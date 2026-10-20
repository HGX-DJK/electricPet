"""
桌面萌宠 - 系统硬件全息感知模块 (System Hardware Monitor)
基于 Windows 原生 NT 内核接口 (kernel32.dll)
提供毫秒级、零第三方外部依赖 (0 Pip Dependency)、高健壮性的 CPU 负载与物理内存监控
"""
import sys
import ctypes
import time
from typing import Dict, Any, Tuple

# Windows 内核结构体定义
class _MEMORYSTATUSEX(ctypes.Structure):
    _fields_ = [
        ("dwLength", ctypes.c_ulong),
        ("dwMemoryLoad", ctypes.c_ulong),
        ("ullTotalPhys", ctypes.c_ulonglong),
        ("ullAvailPhys", ctypes.c_ulonglong),
        ("ullTotalPageFile", ctypes.c_ulonglong),
        ("ullAvailPageFile", ctypes.c_ulonglong),
        ("ullTotalVirtual", ctypes.c_ulonglong),
        ("ullAvailVirtual", ctypes.c_ulonglong),
        ("ullAvailExtendedVirtual", ctypes.c_ulonglong),
    ]

class _FILETIME(ctypes.Structure):
    _fields_ = [
        ("dwLowDateTime", ctypes.c_ulong),
        ("dwHighDateTime", ctypes.c_ulong),
    ]


class SystemHardwareMonitor:
    """Windows 原生系统性能感知单例"""
    _instance = None

    def __new__(cls):
        if cls._instance is None:
            cls._instance = super().__new__(cls)
            cls._instance._init_monitor()
        return cls._instance

    def _init_monitor(self):
        self.is_windows = (sys.platform == "win32")
        self._kernel32 = getattr(ctypes, "windll", None).kernel32 if (self.is_windows and hasattr(ctypes, "windll")) else None
        self._last_idle_time = 0
        self._last_kernel_time = 0
        self._last_user_time = 0
        self._last_cpu_sample_time = 0.0
        self._cached_cpu_percent = 0
        self._cached_stats = {"cpu": 0, "memory": 0, "mem_total_gb": 16.0, "uptime": "0m"}
        self._last_sample_tick = 0.0

        # 初始化 CPU 基准时间戳
        self._last_idle_time, self._last_kernel_time, self._last_user_time = self._sample_cpu_times()
        self._last_cpu_sample_time = time.time()

    def _filetime_to_int(self, ft: _FILETIME) -> int:
        return (ft.dwHighDateTime << 32) + ft.dwLowDateTime

    def _sample_cpu_times(self) -> Tuple[int, int, int]:
        if not self._kernel32:
            return (0, 0, 0)
        idle = _FILETIME()
        kernel = _FILETIME()
        user = _FILETIME()
        res = self._kernel32.GetSystemTimes(
            ctypes.byref(idle),
            ctypes.byref(kernel),
            ctypes.byref(user)
        )
        if res:
            return (
                self._filetime_to_int(idle),
                self._filetime_to_int(kernel),
                self._filetime_to_int(user),
            )
        return (0, 0, 0)

    def get_system_stats(self) -> Dict[str, Any]:
        """
        获取当前系统核心指标 (带 0.8s 节流缓存，避免频繁轮询产生 CPU 额外开销)
        返回: {
            "cpu": int (0~100),
            "memory": int (0~100),
            "mem_total_gb": float,
            "uptime": str (例如 "2h 45m")
        }
        """
        now = time.time()
        if now - self._last_sample_tick < 0.8 and self._cached_stats["memory"] > 0:
            return self._cached_stats

        self._last_sample_tick = now

        if not self._kernel32:
            return self._cached_stats

        # 1. 读取物理内存
        mem_load = 0
        total_gb = 16.0
        try:
            mem = _MEMORYSTATUSEX()
            mem.dwLength = ctypes.sizeof(_MEMORYSTATUSEX)
            if self._kernel32.GlobalMemoryStatusEx(ctypes.byref(mem)):
                mem_load = int(mem.dwMemoryLoad)
                total_gb = round(mem.ullTotalPhys / (1024 ** 3), 1)
        except Exception:
            pass

        # 2. 读取 CPU 占用率
        cpu_load = self._cached_cpu_percent
        try:
            curr_idle, curr_kernel, curr_user = self._sample_cpu_times()
            if self._last_cpu_sample_time > 0 and curr_kernel > 0:
                dt_sample = now - self._last_cpu_sample_time
                if dt_sample >= 0.5:
                    d_idle = curr_idle - self._last_idle_time
                    d_kernel = curr_kernel - self._last_kernel_time
                    d_user = curr_user - self._last_user_time
                    total_sys = d_kernel + d_user
                    if total_sys > 0:
                        busy = total_sys - d_idle
                        calc_cpu = int(max(0.0, min(100.0, (busy / total_sys) * 100.0)))
                        cpu_load = calc_cpu
                        self._cached_cpu_percent = cpu_load
                    self._last_idle_time = curr_idle
                    self._last_kernel_time = curr_kernel
                    self._last_user_time = curr_user
                    self._last_cpu_sample_time = now
            else:
                self._last_idle_time = curr_idle
                self._last_kernel_time = curr_kernel
                self._last_user_time = curr_user
                self._last_cpu_sample_time = now
        except Exception:
            pass

        # 3. 读取系统已开机运行时长
        uptime_str = "0m"
        try:
            # GetTickCount64 返回自开机以来的毫秒数
            ms = self._kernel32.GetTickCount64()
            seconds = int(ms / 1000)
            hours = seconds // 3600
            mins = (seconds % 3600) // 60
            if hours > 0:
                uptime_str = f"{hours}h {mins}m"
            else:
                uptime_str = f"{mins}m"
        except Exception:
            pass

        self._cached_stats = {
            "cpu": cpu_load,
            "memory": mem_load,
            "mem_total_gb": total_gb,
            "uptime": uptime_str,
        }
        return self._cached_stats


# 全局单例接口
system_monitor = SystemHardwareMonitor()

def get_system_stats() -> Dict[str, Any]:
    return system_monitor.get_system_stats()
