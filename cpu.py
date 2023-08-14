import os
import time
import multiprocessing
from psutil import cpu_percent

def cpu_load():
    while True:
        pass

def run_load(target_load=90, duration=120):
    print("Creating CPU load...")
    cpu_cores = multiprocessing.cpu_count()
    pool = multiprocessing.Pool(cpu_cores)
    start_time = time.time()

    while True:
        load = cpu_percent(interval=1)
        if load < target_load:
            pool.apply_async(cpu_load)
        elif load >= target_load and time.time() - start_time < duration:
            time.sleep(1)
        else:
            break

    pool.terminate()
    print("CPU load generation stopped.")

if __name__ == "__main__":
    # Set the target CPU load percentage
    target_load = 90

    # Set the duration for which you want to keep the load in seconds (2 minutes in this case)
    duration = 60

    # Triggering the CPU load
    run_load(target_load, duration)



