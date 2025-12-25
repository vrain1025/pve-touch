<!DOCTYPE html>
<html lang="zh-CN" data-theme="light">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
    <title>PVE Mobile Manager</title>
    <link href="https://cdn.jsdelivr.net/npm/daisyui@4.4.19/dist/full.min.css" rel="stylesheet" type="text/css" />
    <script src="https://cdn.tailwindcss.com"></script>
    <script src="https://unpkg.com/vue@3/dist/vue.global.js"></script>
    <style>
        /* 自定义美化样式 */
        .glass-card {
            background: rgba(255, 255, 255, 0.8);
            backdrop-filter: blur(10px);
            border: 1px solid rgba(255, 255, 255, 0.3);
        }
        .status-pulse {
            display: inline-block;
            width: 8px;
            height: 8px;
            border-radius: 50%;
            margin-right: 6px;
        }
        .status-running { background-color: #22c55e; box-shadow: 0 0 8px #22c55e; animation: pulse 2s infinite; }
        .status-stopped { background-color: #94a3b8; }
        @keyframes pulse {
            0% { opacity: 1; }
            50% { opacity: 0.5; }
            100% { opacity: 1; }
        }
        body { background-color: #f8fafc; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; }
    </style>
</head>
<body>
    <div id="app" v-cloak>
        <div v-if="!isLoggedIn" class="min-h-screen flex items-center justify-center p-4">
            <div class="card w-full max-w-sm bg-base-100 shadow-2xl border border-base-200">
                <div class="card-body">
                    <h2 class="card-title text-2xl font-bold text-center block mb-4 text-primary">PVE 移动管理端</h2>
                    <div class="form-control gap-3">
                        <input v-model="loginForm.username" type="text" placeholder="用户名" class="input input-bordered w-full focus:input-primary" />
                        <input v-model="loginForm.password" type="password" placeholder="密码" class="input input-bordered w-full focus:input-primary" />
                        <select v-model="loginForm.realm" class="select select-bordered w-full">
                            <option value="pam">Linux PAM standard authentication</option>
                            <option value="pve">Proxmox VE authentication server</option>
                        </select>
                        <button @click="handleLogin" :disabled="loading" class="btn btn-primary w-full mt-4">
                            <span v-if="loading" class="loading loading-spinner"></span>
                            {{ loading ? '登录中...' : '立即登录' }}
                        </button>
                    </div>
                </div>
            </div>
        </div>

        <div v-else class="pb-20">
            <div class="navbar bg-base-100/80 backdrop-blur sticky top-0 z-50 px-4 border-b border-base-200">
                <div class="flex-1">
                    <a class="text-xl font-bold bg-gradient-to-r from-primary to-secondary bg-clip-text text-transparent">PVE Dashboard</a>
                </div>
                <div class="flex-none">
                    <button @click="fetchData" class="btn btn-ghost btn-circle">
                        <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" /></svg>
                    </button>
                    <button @click="logout" class="btn btn-ghost btn-circle text-error">
                        <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 16l4-4m0 0l-4-4m4 4H7m6 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h4a3 3 0 013 3v1" /></svg>
                    </button>
                </div>
            </div>

            <div class="p-4 grid gap-4">
                <div v-for="item in resources" :key="item.vmid" 
                     class="card bg-base-100 shadow-sm border border-base-200 hover:shadow-md transition-all active:scale-[0.98]"
                     @click="showDetail(item)">
                    <div class="card-body p-4">
                        <div class="flex justify-between items-start">
                            <div>
                                <div class="flex items-center gap-2">
                                    <span :class="['status-pulse', item.status === 'running' ? 'status-running' : 'status-stopped']"></span>
                                    <h3 class="font-bold text-lg text-base-content">{{ item.name || item.vmid }}</h3>
                                    <div class="badge badge-outline badge-sm opacity-60">ID: {{ item.vmid }}</div>
                                </div>
                                <p class="text-xs text-base-content/60 mt-1 uppercase">{{ item.node }} • {{ item.type }}</p>
                            </div>
                            <div class="dropdown dropdown-end" @click.stop>
                                <label tabindex="0" class="btn btn-ghost btn-xs btn-circle">
                                    <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 5v.01M12 12v.01M12 19v.01M12 6a1 1 0 110-2 1 1 0 010 2zm0 7a1 1 0 110-2 1 1 0 010 2zm0 7a1 1 0 110-2 1 1 0 010 2z" /></svg>
                                </label>
                                <ul tabindex="0" class="dropdown-content z-[1] menu p-2 shadow bg-base-100 rounded-box w-32">
                                    <li v-if="item.status !== 'running'"><a @click="vmControl(item, 'start')" class="text-success">启动</a></li>
                                    <li v-if="item.status === 'running'"><a @click="vmControl(item, 'stop')" class="text-error">停止</a></li>
                                    <li v-if="item.status === 'running'"><a @click="vmControl(item, 'reboot')" class="text-warning">重启</a></li>
                                </ul>
                            </div>
                        </div>

                        <div v-if="item.status === 'running'" class="mt-3 space-y-2">
                            <div class="flex flex-col gap-1">
                                <div class="flex justify-between text-[10px] font-medium uppercase opacity-70">
                                    <span>CPU 使用率</span>
                                    <span>{{ (item.cpu * 100).toFixed(1) }}%</span>
                                </div>
                                <progress class="progress progress-primary h-1.5" :value="item.cpu * 100" max="100"></progress>
                            </div>
                            <div class="flex flex-col gap-1">
                                <div class="flex justify-between text-[10px] font-medium uppercase opacity-70">
                                    <span>内存分配</span>
                                    <span>{{ formatSize(item.mem) }} / {{ formatSize(item.maxmem) }}</span>
                                </div>
                                <progress class="progress progress-secondary h-1.5" :value="(item.mem / item.maxmem) * 100" max="100"></progress>
                            </div>
                        </div>
                    </div>
                </div>
            </div>

            <div v-if="resources.length === 0 && !loading" class="text-center py-20 opacity-40">
                <p>暂无正在运行的虚拟机/容器</p>
            </div>
        </div>

        <dialog id="vm_modal" class="modal modal-bottom sm:modal-middle">
            <div class="modal-box p-0 bg-base-200">
                <div class="p-6 bg-base-100 rounded-b-3xl shadow-sm">
                    <h3 class="font-bold text-xl mb-4">详情: {{ selectedVM?.name }}</h3>
                    <div class="grid grid-cols-2 gap-4">
                        <div class="bg-base-200 p-3 rounded-xl text-center">
                            <div class="text-xs opacity-50 uppercase">核心数</div>
                            <div class="font-bold text-lg text-primary">{{ selectedVM?.cpus || '-' }}</div>
                        </div>
                        <div class="bg-base-200 p-3 rounded-xl text-center">
                            <div class="text-xs opacity-50 uppercase">总内存</div>
                            <div class="font-bold text-lg text-secondary">{{ formatSize(selectedVM?.maxmem) }}</div>
                        </div>
                    </div>
                </div>
                <div class="p-6 space-y-4">
                    <button v-if="selectedVM?.status !== 'running'" @click="vmControl(selectedVM, 'start')" class="btn btn-success btn-block text-white shadow-lg shadow-success/20">一键启动</button>
                    <div v-else class="grid grid-cols-2 gap-4">
                        <button @click="vmControl(selectedVM, 'reboot')" class="btn btn-warning text-white">重启</button>
                        <button @click="vmControl(selectedVM, 'stop')" class="btn btn-error text-white">停止</button>
                    </div>
                    <form method="dialog">
                        <button class="btn btn-ghost btn-block">返回列表</button>
                    </form>
                </div>
            </div>
            <form method="dialog" class="modal-backdrop">
                <button>close</button>
            </form>
        </dialog>

        <div class="toast toast-top toast-center z-[100]">
            <div v-for="msg in toasts" :key="msg.id" :class="['alert shadow-lg', msg.type === 'error' ? 'alert-error text-white' : 'alert-success text-white']">
                <span>{{ msg.text }}</span>
            </div>
        </div>
    </div>

    <script>
        const { createApp, ref, onMounted, reactive } = Vue;

        createApp({
            setup() {
                const isLoggedIn = ref(!!localStorage.getItem('pve_ticket'));
                const loading = ref(false);
                const resources = ref([]);
                const selectedVM = ref(null);
                const toasts = ref([]);
                const loginForm = reactive({
                    username: '',
                    password: '',
                    realm: 'pam'
                });

                // 工具函数
                const showToast = (text, type = 'success') => {
                    const id = Date.now();
                    toasts.value.push({ id, text, type });
                    setTimeout(() => {
                        toasts.value = toasts.value.filter(t => t.id !== id);
                    }, 3000);
                };

                const formatSize = (bytes) => {
                    if (!bytes) return '0B';
                    const k = 1024;
                    const sizes = ['B', 'KB', 'MB', 'GB', 'TB'];
                    const i = Math.floor(Math.log(bytes) / Math.log(k));
                    return parseFloat((bytes / Math.pow(k, i)).toFixed(1)) + sizes[i];
                };

                // API 请求封装
                const apiFetch = async (url, options = {}) => {
                    const ticket = localStorage.getItem('pve_ticket');
                    const csrftoken = localStorage.getItem('pve_csrftoken');
                    
                    const defaultHeaders = {
                        'CSRFPreventionToken': csrftoken || '',
                        'Cookie': ticket ? `PVEAuthCookie=${ticket}` : ''
                    };

                    try {
                        const response = await fetch(url, {
                            ...options,
                            headers: { ...defaultHeaders, ...options.headers }
                        });
                        if (response.status === 401) {
                            logout();
                            throw new Error('会话过期，请重新登录');
                        }
                        return await response.json();
                    } catch (err) {
                        showToast(err.message, 'error');
                        throw err;
                    }
                };

                const handleLogin = async () => {
                    loading.value = true;
                    try {
                        // 模拟 PVE 登录接口
                        const res = await fetch('/api2/json/access/ticket', {
                            method: 'POST',
                            body: new URLSearchParams(loginForm)
                        });
                        const data = await res.json();
                        if (data.data) {
                            localStorage.setItem('pve_ticket', data.data.ticket);
                            localStorage.setItem('pve_csrftoken', data.data.CSRFPreventionToken);
                            isLoggedIn.value = true;
                            fetchData();
                        } else {
                            showToast('登录失败，请检查账号密码', 'error');
                        }
                    } catch (e) {
                        showToast('网络连接失败', 'error');
                    } finally {
                        loading.value = false;
                    }
                };

                const fetchData = async () => {
                    loading.value = true;
                    try {
                        const res = await apiFetch('/api2/json/cluster/resources?type=vm');
                        resources.value = res.data || [];
                    } catch (e) {} finally {
                        loading.value = false;
                    }
                };

                const vmControl = async (vm, action) => {
                    if (!confirm(`确定要执行 ${action} 操作吗?`)) return;
                    try {
                        await apiFetch(`/api2/json/nodes/${vm.node}/${vm.type}/${vm.vmid}/status/${action}`, { method: 'POST' });
                        showToast(`指令 ${action} 已发送`);
                        setTimeout(fetchData, 1000);
                    } catch (e) {}
                };

                const showDetail = (vm) => {
                    selectedVM.value = vm;
                    document.getElementById('vm_modal').showModal();
                };

                const logout = () => {
                    localStorage.clear();
                    isLoggedIn.value = false;
                };

                onMounted(() => {
                    if (isLoggedIn.value) fetchData();
                });

                return {
                    isLoggedIn, loading, resources, selectedVM, loginForm, toasts,
                    handleLogin, logout, fetchData, formatSize, vmControl, showDetail
                };
            }
        }).mount('#app');
    </script>
</body>
</html>
