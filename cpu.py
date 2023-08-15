import multiprocessing
import time

def load_cpu(load_percentage, interval):
    """
    A function that generates a specific load on the CPU.
    """
    work_time = interval * load_percentage
    sleep_time = interval - work_time

    while True:
        end_time = time.time() + work_time
        while time.time() < end_time:
            x = (0.00001*3.14*3.14) / 2.34  # some CPU-bound task
        time.sleep(sleep_time)

NUM_PROCESSES = 1
LOAD_PERCENTAGE = 0.80  # 80% load
INTERVAL = 1.0  # interval in seconds

if __name__ == "__main__":
    processes = []

    for _ in range(NUM_PROCESSES):
        process = multiprocessing.Process(target=load_cpu, args=(LOAD_PERCENTAGE, INTERVAL))
        processes.append(process)
        process.start()

    try:
        while True:
            time.sleep(1)  # Keep the script running
    except KeyboardInterrupt:
        for process in processes:
            process.terminate()
