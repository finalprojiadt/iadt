import os
import time
import multiprocessing
import threading
from psutil import cpu_percent

def cpu_load():
    while True:
        pass

def monitor_cpu(terminate_event):
    while not terminate_event.is_set():
        time.sleep(10)
        load = cpu_percent(interval=1)
        if load >= 90:
            print("CPU usage reached 90%, stopping script.")
            os._exit(0)  # forcibly terminates the process

def run_load(target_load1=80, duration1=60, target_load2=90):
    print("Creating CPU load...")
    cpu_cores = multiprocessing.cpu_count()
    pool = multiprocessing.Pool(cpu_cores)
    start_time = time.time()

    terminate_event = threading.Event()
    monitor_thread = threading.Thread(target=monitor_cpu, args=(terminate_event,))
    monitor_thread.start()

    # Gradually increase the load to target_load1
    for load_target in range(target_load1 + 1):
        while cpu_percent(interval=1) < load_target:
            pool.apply_async(cpu_load)
        time.sleep(1)

    print(f"Reached {target_load1}% load, maintaining for {duration1} seconds...")

    # Maintain the load for duration1 seconds
    start_maintain_time = time.time()
    while time.time() - start_maintain_time < duration1:
        load = cpu_percent(interval=1)
        if load < target_load1:
            pool.apply_async(cpu_load)
        time.sleep(1)

    print(f"Increasing load to {target_load2}%...")

    # Gradually increase the load to target_load2
    for load_target in range(target_load1 + 1, target_load2 + 1):
        while cpu_percent(interval=1) < load_target:
            pool.apply_async(cpu_load)
        time.sleep(1)

    print(f"Reached {target_load2}% load, stopping script.")
    terminate_event.set()
    pool.terminate()
    print("CPU load generation stopped.")

if __name__ == "__main__":
    run_load()
