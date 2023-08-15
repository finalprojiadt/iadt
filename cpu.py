import os
import time
import multiprocessing
from psutil import cpu_percent

def cpu_load():
    while True:
        pass

def run_load(target_load1=75, target_load2=90, duration1=10, duration2=30):
    print("Creating CPU load...")
    cpu_cores = multiprocessing.cpu_count()
    pool = multiprocessing.Pool(cpu_cores)
    start_time = time.time()

    # Gradually increase the load to target_load1
    for load_target in range(target_load1 + 1):
        while cpu_percent(interval=1) < load_target:
            pool.apply_async(cpu_load)
        time.sleep(duration1 / target_load1)

    print("Reached 75% load, maintaining for 30 seconds...")

    # Maintain the load for duration2 seconds
    start_maintain_time = time.time()
    while time.time() - start_maintain_time < duration2:
        load = cpu_percent(interval=1)
        if load < target_load1:
            pool.apply_async(cpu_load)
        time.sleep(1)

    print("Increasing load to 90%...")

    # Gradually increase the load to target_load2
    for load_target in range(target_load1 + 1, target_load2 + 1):
        while cpu_percent(interval=1) < load_target:
            pool.apply_async(cpu_load)
        time.sleep(1)

    print("Reached 90% load, stopping script.")

    pool.terminate()
    print("CPU load generation stopped.")

if __name__ == "__main__":
    run_load()




