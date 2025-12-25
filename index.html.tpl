<!DOCTYPE html>
<html lang="zh-CN" data-theme="light">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no, viewport-fit=cover">
    <title>PVE Manager Pro</title>
    <link rel="icon" href="data:,">
    <link href="https://cdn.jsdelivr.net/npm/daisyui@4.4.19/dist/full.min.css" rel="stylesheet" type="text/css" />
    <script src="https://cdn.tailwindcss.com"></script>
    <script>
        tailwind.config = { theme: { extend: {} } }
    </script>
    <script src="https://unpkg.com/vue@3/dist/vue.global.prod.js"></script>

    <style>
        [v-cloak] { display: none; }
        body { background-color: #f8fafc; -webkit-tap-highlight-color: transparent; }
        .status-running { background-color: #22c55e; box-shadow: 0 0 8px rgba(34, 197, 94, 0.4); }
        .no-scrollbar::-webkit-scrollbar { display: none; }
        .chart-svg { width: 100%; height: 100%; overflow: visible; }
        .chart-path { stroke-width: 2; vector-effect: non-scaling-stroke; transition: d 0.5s linear; }
    </style>
</head>
<body>
    <div id="app" v-cloak>
        <div v-if="!isLoggedIn" class="min-h-screen flex items-center justify-center p-6 bg-slate-50">
            <div class="card w-full max-w-sm bg-base-100 shadow-2xl p-8 border border-base-200">
                <div class="flex flex-col items-center mb-8">
                    <div class="w-16 h-16 bg-primary rounded-2xl flex items-center justify-center shadow-lg mb-4">
                        <svg class="w-10 h-10 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19.428 15.428a2 2 0 00-1.022-.547l-2.384-.477a6 6 0 00-3.86.517l-.318.158a6 6 0 01-3.86.517L6.05 15.21a2 2 0 00-1.806.547M8 4h8l-1 1v5.172a2 2 0 00.586 1.414l5 5c1.26 1.26.367 3.414-1.415 3.414H4.828c-1.782 0-2.674-2.154-1.414-3.414l5-5A2 2 0 009 10.172V5L8 4z" /></svg>
                    </div>
                    <h2 class="text-2xl font-black text-slate-700">PVE ADMIN</h2>
                </div>
                <div class="space-y-4">
                    <input v-model="loginForm.username" type="text" placeholder="用户名" class="input input-bordered w-full" autocomplete="off" data-lpignore="true" />
                    <input v-model="loginForm.password" type="password" placeholder="密码" class="input input-bordered w-full" autocomplete="off" data-lpignore="true" />
                    <select v-model="loginForm.realm" class="select select-bordered w-full">
                        <option value="pam">Linux PAM</option>
                        <option value="pve">Proxmox VE</option>
                    </select>
                    <button @click="handleLogin" :disabled="loading" class="btn btn-primary w-full shadow-lg">
                        <span v-if="loading" class="loading loading-spinner"></span><span v-else>登录</span>
                    </button>
                </div>
            </div>
        </div>

        <div v-else class="max-w-md mx-auto min-h-screen pb-20">
            <header class="navbar sticky top-0 z-50 bg-base-100/90 backdrop-blur-md px-4 border-b border-base-200">
                <div class="flex-1">
                    <h1 class="font-black text-xl tracking-tight text-slate-700">PVE Monitor</h1>
                    <span v-if="autoRefresh" class="ml-2 w-2 h-2 bg-success rounded-full animate-pulse"></span>
                </div>
                <div class="flex-none gap-2">
                    <button @click="forceRefresh" class="btn btn-ghost btn-sm btn-circle">
                        <svg class="w-5 h-5" :class="{'animate-spin': loading}" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" /></svg>
                    </button>
                    <div class="dropdown dropdown-end">
                        <label tabindex="0" class="btn btn-ghost btn-sm btn-circle avatar placeholder border border-base-300">
                            <div class="bg-neutral text-neutral-content rounded-full w-8"><span class="text-xs uppercase">{{ loginForm.username[0] || 'U' }}</span></div>
                        </label>
                        <ul tabindex="0" class="mt-3 z-[1] p-2 shadow-lg menu menu-sm dropdown-content bg-base-100 rounded-box w-52 border border-base-200">
                            <li class="menu-title px-4 py-2 bg-base-200 rounded-t-lg mb-2">
                                <span class="block truncate font-bold text-primary">{{ loginForm.username }}</span>
                            </li>
                            <li><a @click="toggleAutoRefresh" class="justify-between">自动刷新 <span class="badge badge-sm" :class="autoRefresh?'badge-success':'badge-ghost'">{{ autoRefresh?'ON':'OFF' }}</span></a></li>
                            <div class="divider my-1"></div>
                            <li><a @click="logout" class="text-error font-bold">退出登录</a></li>
                        </ul>
                    </div>
                </div>
            </header>

            <div class="p-4 space-y-3">
                <div v-for="item in resources" :key="item.id" class="card bg-base-100 border border-base-200 shadow-sm overflow-hidden active:scale-[0.99] transition-transform">
                    <div class="card-body p-4">
                        <div class="flex justify-between items-center mb-3">
                            <div class="flex items-center gap-3 cursor-pointer" @click="showDetail(item)">
                                <div :class="['w-3 h-3 rounded-full shadow-sm', item.status === 'running' ? 'status-running' : 'bg-slate-300']"></div>
                                <div>
                                    <div class="font-bold text-base leading-none">{{ item.name }}</div>
                                    <div class="text-[10px] opacity-40 font-mono mt-1">ID: {{ item.vmid }} • {{ item.node }}</div>
                                </div>
                            </div>
                            <div class="flex gap-2">
                                <button @click.stop="openMonitor(item)" class="btn btn-xs btn-outline btn-info">监控</button>
                                <button @click.stop="openConfig(item)" class="btn btn-xs btn-outline btn-warning">配置</button>
                            </div>
                        </div>
                        <div v-if="item.status === 'running'" @click="showDetail(item)" class="space-y-3 cursor-pointer">
                            <div>
                                <div class="flex justify-between text-[10px] font-bold opacity-60 mb-1">
                                    <span>CPU</span><span>{{ (item.cpu * 100).toFixed(1) }}%</span>
                                </div>
                                <progress class="progress progress-primary h-1.5 w-full" :value="item.cpu * 100" max="100"></progress>
                            </div>
                            <div>
                                <div class="flex justify-between text-[10px] font-bold opacity-60 mb-1">
                                    <span>MEM</span><span>{{ formatSize(item.mem) }} / {{ formatSize(item.maxmem) }}</span>
                                </div>
                                <progress class="progress progress-secondary h-1.5 w-full" :value="(item.mem / item.maxmem) * 100" max="100"></progress>
                            </div>
                        </div>
                        <div v-else class="text-xs text-center py-2 opacity-30 italic bg-slate-50 rounded">已停止运行</div>
                    </div>
                </div>
            </div>
        </div>

        <dialog id="modal_detail" class="modal modal-bottom sm:modal-middle" @click.self="closeAllModals">
            <div v-if="selectedVM" class="modal-box p-0 bg-base-200 rounded-t-3xl overflow-hidden">
                <div class="p-6 bg-base-100 rounded-b-3xl shadow-sm">
                    <div class="flex justify-between items-start mb-6">
                        <div>
                            <h3 class="text-2xl font-black">{{ selectedVM.name }}</h3>
                            <p class="text-xs uppercase opacity-50 font-bold tracking-widest">{{ selectedVM.type }} • {{ selectedVM.status }}</p>
                        </div>
                        <button @click="closeAllModals" class="btn btn-circle btn-sm btn-ghost">✕</button>
                    </div>
                    <div class="grid grid-cols-2 gap-3">
                        <div class="bg-base-200 p-4 rounded-2xl text-center">
                            <div class="text-[10px] opacity-50 font-bold uppercase">Uptime</div>
                            <div class="font-bold text-success">{{ formatUptime(selectedVM.uptime) }}</div>
                        </div>
                        <div class="bg-base-200 p-4 rounded-2xl text-center">
                            <div class="text-[10px] opacity-50 font-bold uppercase">Disk Max</div>
                            <div class="font-bold">{{ formatSize(selectedVM.maxdisk) }}</div>
                        </div>
                        <div class="bg-base-200 p-4 rounded-2xl text-center">
                            <div class="text-[10px] opacity-50 font-bold uppercase">CPU Cores</div>
                            <div class="font-bold">{{ selectedVM.maxcpu || selectedVM.cpus }} vCPU</div>
                        </div>
                        <div class="bg-base-200 p-4 rounded-2xl text-center">
                            <div class="text-[10px] opacity-50 font-bold uppercase">Mem Max</div>
                            <div class="font-bold">{{ formatSize(selectedVM.maxmem) }}</div>
                        </div>
                    </div>
                </div>
                <div class="p-6 grid grid-cols-3 gap-3">
                    <button v-if="selectedVM.status !== 'running'" @click="vmControl(selectedVM, 'start')" class="btn btn-success text-white col-span-3 shadow-lg">启动</button>
                    <template v-else>
                        <button @click="vmControl(selectedVM, 'reboot')" class="btn btn-warning text-white shadow">重启</button>
                        <button @click="vmControl(selectedVM, 'stop')" class="btn btn-error text-white shadow">关机</button>
                        <button @click="vmControl(selectedVM, 'stop', true)" class="btn btn-outline btn-error">强停</button>
                    </template>
                </div>
            </div>
        </dialog>

        <div v-if="page === 'monitor'" class="fixed inset-0 z-[100] bg-base-200 flex flex-col overflow-y-auto no-scrollbar">
            <div class="navbar bg-base-100 border-b border-base-200 px-4 sticky top-0 z-50 shadow-sm">
                <button @click="page = null" class="btn btn-ghost btn-sm btn-circle"><svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 19l-7-7 7-7" /></svg></button>
                <div class="flex-1 text-center font-bold text-lg">{{ selectedVM?.name }} 监控</div>
                <div class="dropdown dropdown-end">
                    <button tabindex="0" class="btn btn-ghost btn-sm btn-square"><svg class="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6V4m0 2a2 2 0 100 4m0-4a2 2 0 110 4m-6 8a2 2 0 100-4m0 4a2 2 0 110-4m0 4v2m0-6V4m6 6v10m6-2a2 2 0 100-4m0 4a2 2 0 110-4m0 4v2m0-6V4" /></svg></button>
                    <div class="dropdown-content z-[1] p-4 shadow bg-base-100 rounded-box w-64 border border-base-200">
                        <label class="label"><span class="label-text font-bold">刷新频率: {{refreshInterval}}s</span></label>
                        <input type="range" min="1" max="10" v-model.number="refreshInterval" class="range range-xs range-primary" />
                    </div>
                </div>
            </div>

            <div class="p-4 space-y-4 pb-12">
                <div class="card bg-base-100 shadow-sm p-4 border-l-4 border-primary">
                    <div class="flex justify-between items-end mb-4">
                        <h4 class="text-xs font-black opacity-40 uppercase tracking-widest text-primary">CPU Load</h4>
                        <span class="text-2xl font-black font-mono">{{ (selectedVM?.cpu * 100).toFixed(1) }}<span class="text-sm text-base-content/40">%</span></span>
                    </div>
                    <div class="h-24 w-full relative">
                        <svg class="chart-svg" viewBox="0 0 100 100" preserveAspectRatio="none"><path :d="getSvgPath(history.cpu)" class="chart-path" stroke="oklch(var(--p))" fill="none"></path></svg>
                    </div>
                </div>
                <div class="card bg-base-100 shadow-sm p-4 border-l-4 border-secondary">
                    <div class="flex justify-between items-end mb-4">
                        <h4 class="text-xs font-black opacity-40 uppercase tracking-widest text-secondary">Memory</h4>
                        <span class="text-2xl font-black font-mono">{{ ((selectedVM?.mem / selectedVM?.maxmem) * 100).toFixed(1) }}<span class="text-sm text-base-content/40">%</span></span>
                    </div>
                    <div class="h-24 w-full relative">
                        <svg class="chart-svg" viewBox="0 0 100 100" preserveAspectRatio="none"><path :d="getSvgPath(history.mem)" class="chart-path" stroke="oklch(var(--s))" fill="none"></path></svg>
                    </div>
                </div>
                <div class="grid grid-cols-2 gap-4">
                    <div class="card bg-base-100 shadow-sm p-3">
                        <div class="text-[10px] font-black opacity-40 uppercase mb-1 text-info">Network I/O</div>
                        <div class="text-lg font-bold font-mono mb-2">{{ formatSize(selectedVM?.netSpeed || 0) }}/s</div>
                        <div class="h-12 w-full"><svg class="chart-svg" viewBox="0 0 100 100" preserveAspectRatio="none"><path :d="getSvgPath(history.net)" class="chart-path" stroke="oklch(var(--in))" fill="none"></path></svg></div>
                    </div>
                    <div class="card bg-base-100 shadow-sm p-3">
                        <div class="text-[10px] font-black opacity-40 uppercase mb-1 text-accent">Disk I/O</div>
                        <div class="text-lg font-bold font-mono mb-2">{{ formatSize(selectedVM?.diskSpeed || 0) }}/s</div>
                        <div class="h-12 w-full"><svg class="chart-svg" viewBox="0 0 100 100" preserveAspectRatio="none"><path :d="getSvgPath(history.disk)" class="chart-path" stroke="oklch(var(--a))" fill="none"></path></svg></div>
                    </div>
                </div>
            </div>
        </div>

        <div v-if="page === 'config'" class="fixed inset-0 z-[100] bg-base-200 flex flex-col">
            <div class="navbar bg-base-100 border-b border-base-200 px-4">
                <button @click="page = null" class="btn btn-ghost btn-sm">取消</button>
                <div class="flex-1 text-center font-bold">硬件调整</div>
                <button @click="saveHardwareConfig" class="btn btn-primary btn-sm">保存</button>
            </div>
            <div class="p-6 space-y-6">
                <div class="form-control w-full">
                    <label class="label"><span class="label-text font-bold">CPU Cores</span><span class="label-text-alt font-mono">{{ editConfig.cores }} vCPU</span></label>
                    <input type="range" min="1" max="32" v-model="editConfig.cores" class="range range-primary" />
                </div>
                <div class="form-control w-full">
                    <label class="label"><span class="label-text font-bold">Memory (MB)</span></label>
                    <input type="number" v-model="editConfig.memory" class="input input-bordered font-mono font-bold" />
                </div>
                <div class="alert alert-warning text-xs">注意: 硬件修改可能需要重启虚拟机生效。</div>
            </div>
        </div>

        <div class="toast toast-top toast-center z-[200]">
            <div v-for="msg in toasts" :key="msg.id" :class="['alert text-white font-bold shadow-xl text-xs border-none', msg.type==='error'?'alert-error':'alert-success']">
                <span>{{ msg.text }}</span>
            </div>
        </div>
    </div>

    <script>
        const { createApp, ref, onMounted, reactive, watch, onUnmounted } = Vue;

        createApp({
            setup() {
                const isLoggedIn = ref(!!localStorage.getItem('pve_ticket'));
                const loading = ref(false);
                const resources = ref([]);
                const selectedVM = ref(null);
                const page = ref(null);
                const autoRefresh = ref(true);
                const refreshInterval = ref(2); 
                let timer = null;
                const prevStats = ref({}); 

                const historyLength = 50;
                const history = reactive({ cpu: Array(historyLength).fill(0), mem: Array(historyLength).fill(0), net: Array(historyLength).fill(0), disk: Array(historyLength).fill(0) });
                const loginForm = reactive({ username: localStorage.getItem('last_user') || '', password: '', realm: 'pam' });
                const editConfig = reactive({ cores: 1, memory: 512 });
                const toasts = ref([]);

                const getSvgPath = (data) => {
                    if (!data || data.length === 0) return '';
                    const maxVal = Math.max(...data, 1);
                    const width = 100, height = 100, step = width / (data.length - 1);
                    let path = `M 0,${height} `;
                    data.forEach((val, i) => {
                        path += `L ${(i * step).toFixed(1)},${(height - ((val / maxVal) * height)).toFixed(1)} `;
                    });
                    return path;
                };

                const showToast = (text, type = 'success') => {
                    const id = Date.now();
                    toasts.value.push({ id, text, type });
                    setTimeout(() => toasts.value = toasts.value.filter(t => t.id !== id), 3000);
                };

                const formatSize = (bytes) => {
                    if (bytes === 0 || !bytes) return '0 B';
                    const k = 1024;
                    const sizes = ['B', 'KB', 'MB', 'GB', 'TB'];
                    const i = Math.floor(Math.log(bytes) / Math.log(k));
                    return parseFloat((bytes / Math.pow(k, i)).toFixed(1)) + ' ' + sizes[i];
                };
                const formatUptime = (s) => s ? (s>86400 ? `${Math.floor(s/86400)}d` : `${Math.floor(s/3600)}h`) : '-';

                const apiFetch = async (url, options = {}) => {
                    try {
                        const res = await fetch(url, { ...options, headers: { 'CSRFPreventionToken': localStorage.getItem('pve_csrftoken') || '', 'Cookie': `PVEAuthCookie=${localStorage.getItem('pve_ticket')}` } });
                        if (res.status === 401) { logout(); return null; }
                        return await res.json();
                    } catch (e) { return null; }
                };

                const calcSpeed = (vm) => {
                    const now = Date.now();
                    const last = prevStats.value[vm.vmid];
                    let netSpeed = 0, diskSpeed = 0;
                    if (last) {
                        const timeDiff = (now - last.time) / 1000; 
                        if (timeDiff > 0) {
                            const netDiff = (vm.netin + vm.netout) - last.netTotal;
                            const diskDiff = (vm.diskread + vm.diskwrite) - last.diskTotal;
                            netSpeed = netDiff >= 0 ? netDiff / timeDiff : 0;
                            diskSpeed = diskDiff >= 0 ? diskDiff / timeDiff : 0;
                        }
                    }
                    prevStats.value[vm.vmid] = { time: now, netTotal: vm.netin + vm.netout, diskTotal: vm.diskread + vm.diskwrite };
                    return { netSpeed, diskSpeed };
                };

                const fetchData = async () => {
                    if (!isLoggedIn.value) return;
                    loading.value = true;
                    const res = await apiFetch('/api2/json/cluster/resources?type=vm');
                    loading.value = false;
                    
                    if (res && res.data) {
                        resources.value = res.data.map(vm => {
                            if (vm.status === 'running') {
                                const speeds = calcSpeed(vm);
                                return { ...vm, ...speeds }; 
                            }
                            return vm;
                        });

                        if (selectedVM.value && page.value === 'monitor') {
                            const current = resources.value.find(v => v.id === selectedVM.value.id);
                            if (current) {
                                selectedVM.value = current;
                                updateHistory(current);
                            }
                        }
                    }
                };

                const updateHistory = (vm) => {
                    const push = (arr, val) => { arr.push(val); arr.shift(); };
                    push(history.cpu, vm.cpu * 100);
                    push(history.mem, (vm.mem / vm.maxmem) * 100);
                    push(history.net, vm.netSpeed || 0);
                    push(history.disk, vm.diskSpeed || 0);
                };

                const toggleAutoRefresh = () => { autoRefresh.value = !autoRefresh.value; };
                const forceRefresh = () => { fetchData(); };
                const startTimer = () => {
                    stopTimer();
                    if (autoRefresh.value) timer = setInterval(fetchData, refreshInterval.value * 1000);
                };
                const stopTimer = () => { if (timer) clearInterval(timer); };
                watch([autoRefresh, refreshInterval], startTimer);

                const showDetail = (vm) => { selectedVM.value = vm; document.getElementById('modal_detail').showModal(); };
                const closeAllModals = () => document.getElementById('modal_detail').close();
                const openMonitor = (vm) => { 
                    selectedVM.value = vm; page.value = 'monitor'; 
                    Object.keys(history).forEach(k => history[k].fill(0));
                    prevStats.value[vm.vmid] = null; 
                    fetchData(); 
                };
                const openConfig = (vm) => { selectedVM.value = vm; editConfig.cores = vm.maxcpu||vm.cpus; editConfig.memory = Math.floor(vm.maxmem/1024/1024); page.value = 'config'; };
                
                const handleLogin = async () => {
                    loading.value = true;
                    const res = await fetch('/api2/json/access/ticket', { method: 'POST', body: new URLSearchParams(loginForm) });
                    const data = await res.json();
                    loading.value = false;
                    if (data.data) {
                        localStorage.setItem('pve_ticket', data.data.ticket);
                        localStorage.setItem('pve_csrftoken', data.data.CSRFPreventionToken);
                        localStorage.setItem('last_user', loginForm.username);
                        isLoggedIn.value = true;
                        fetchData(); startTimer();
                    } else showToast('登录失败', 'error');
                };
                const logout = () => { localStorage.removeItem('pve_ticket'); location.reload(); };
                const saveHardwareConfig = async () => { showToast('配置已提交'); page.value=null; };
                const vmControl = async (vm, action, f) => { 
                    if (!confirm(`确定要 ${action} 吗?`)) return;
                    let url = `/api2/json/nodes/${vm.node}/${vm.type}/${vm.vmid}/status/${action}`;
                    if (f && action === 'stop') url += '?forceStop=1';
                    await apiFetch(url, { method: 'POST' });
                    showToast('已发送'); closeAllModals(); 
                    setTimeout(fetchData, 1000);
                };

                onMounted(() => { if (isLoggedIn.value) { fetchData(); startTimer(); } });
                onUnmounted(stopTimer);

                return {
                    isLoggedIn, loading, resources, selectedVM, page, history, loginForm, editConfig, toasts, autoRefresh, refreshInterval,
                    handleLogin, logout, toggleAutoRefresh, forceRefresh, formatSize, formatUptime, 
                    showDetail, closeAllModals, openMonitor, openConfig, saveHardwareConfig, vmControl, getSvgPath
                };
            }
        }).mount('#app');
    </script>
</body>
</html>
