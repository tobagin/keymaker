/*
 * SSHer - Simple Task Queue
 * 
 * Manages background operations with priority levels.
 */

namespace KeyMaker {
    
    /**
     * Priority levels for queued operations
     */
    public enum TaskPriority {
        LOW = 0,
        NORMAL = 1,
        HIGH = 2,
        URGENT = 3
    }
    
    /**
     * Simple task queue for background processing
     */
    public class TaskQueue : Object {
        
        public signal void task_started(string task_id);
        public signal void task_completed(string task_id, bool success, string? error_message);
        public signal void queue_empty();
        
        private static TaskQueue _instance;
        private Gee.HashMap<TaskPriority, GenericArray<QueuedTask>> priority_queues;
        private bool is_processing;
        private int max_concurrent_operations;
        private int current_operations;
        private Cancellable global_cancellable;
        
        public static TaskQueue get_instance() {
            if (_instance == null) {
                _instance = new TaskQueue();
            }
            return _instance;
        }
        
        construct {
            priority_queues = new Gee.HashMap<TaskPriority, GenericArray<QueuedTask>>();
            
            // Initialize priority queues
            priority_queues.set(TaskPriority.URGENT, new GenericArray<QueuedTask>());
            priority_queues.set(TaskPriority.HIGH, new GenericArray<QueuedTask>());
            priority_queues.set(TaskPriority.NORMAL, new GenericArray<QueuedTask>());
            priority_queues.set(TaskPriority.LOW, new GenericArray<QueuedTask>());
            
            max_concurrent_operations = 3;
            current_operations = 0;
            is_processing = false;
            global_cancellable = new Cancellable();
        }
        
        /**
         * Add a task to the queue
         */
        public string add_task(TaskExecutor executor, TaskPriority priority = TaskPriority.NORMAL, string? description = null) {
            var task = new QueuedTask(executor, priority, description);
            
            var priority_queue = priority_queues.get(priority);
            priority_queue.add(task);
            
            KeyMaker.Log.debug("TASK_QUEUE", "Added task %s with priority %s", 
                             task.id, priority.to_string());
            
            if (!is_processing) {
                process_queue.begin();
            }
            
            return task.id;
        }
        
        /**
         * Cancel a queued task
         */
        public bool cancel_task(string task_id) {
            foreach (var entry in priority_queues.entries) {
                var priority_queue = entry.value;
                for (int i = 0; i < priority_queue.length; i++) {
                    var task = priority_queue[i];
                    if (task.id == task_id) {
                        task.cancel();
                        priority_queue.remove_index(i);
                        KeyMaker.Log.debug("TASK_QUEUE", "Cancelled task %s", task_id);
                        return true;
                    }
                }
            }
            return false;
        }
        
        /**
         * Cancel all tasks
         */
        public void cancel_all() {
            global_cancellable.cancel();
            
            foreach (var entry in priority_queues.entries) {
                var priority_queue = entry.value;
                for (int i = 0; i < priority_queue.length; i++) {
                    priority_queue[i].cancel();
                }
                priority_queue.remove_range(0, priority_queue.length);
            }
            
            current_operations = 0;
            is_processing = false;
            
            KeyMaker.Log.info("TASK_QUEUE", "Cancelled all tasks");
        }
        
        /**
         * Process tasks from the queue
         */
        private async void process_queue() {
            is_processing = true;
            
            while (has_pending_tasks() && !global_cancellable.is_cancelled()) {
                // Don't exceed max concurrent operations
                if (current_operations >= max_concurrent_operations) {
                    yield wait_for_slot();
                    continue;
                }
                
                var next_task = get_next_task();
                if (next_task != null) {
                    current_operations++;
                    execute_task.begin(next_task);
                } else {
                    break;
                }
            }
            
            // Wait for all operations to complete
            while (current_operations > 0) {
                yield wait_for_slot();
            }
            
            is_processing = false;
            queue_empty();
        }
        
        /**
         * Execute a single task
         */
        private async void execute_task(QueuedTask task) {
            try {
                KeyMaker.Log.debug("TASK_QUEUE", "Starting task %s: %s", task.id, task.description ?? "unnamed task");
                task_started(task.id);
                
                yield task.execute();
                
                KeyMaker.Log.debug("TASK_QUEUE", "Completed task %s successfully", task.id);
                task_completed(task.id, true, null);
                
            } catch (Error e) {
                if (!(e is IOError.CANCELLED)) {
                    KeyMaker.Log.warning("TASK_QUEUE", "Task %s failed: %s", task.id, e.message);
                }
                task_completed(task.id, false, e.message);
            } finally {
                current_operations--;
            }
        }
        
        /**
         * Get the next task to execute based on priority
         */
        private QueuedTask? get_next_task() {
            TaskPriority[] priorities = {
                TaskPriority.URGENT,
                TaskPriority.HIGH,
                TaskPriority.NORMAL,
                TaskPriority.LOW
            };
            
            foreach (var priority in priorities) {
                var priority_queue = priority_queues.get(priority);
                if (priority_queue.length > 0) {
                    var task = priority_queue[0];
                    priority_queue.remove_index(0);
                    return task;
                }
            }
            
            return null;
        }
        
        /**
         * Check if there are pending tasks
         */
        private bool has_pending_tasks() {
            foreach (var entry in priority_queues.entries) {
                if (entry.value.length > 0) {
                    return true;
                }
            }
            return false;
        }
        
        /**
         * Wait for an operation slot to become available
         */
        private async void wait_for_slot() {
            // Simple polling - wait 50ms and check again
            Timeout.add(50, wait_for_slot.callback);
            yield;
        }
        
        /**
         * Get queue statistics
         */
        public TaskStats get_stats() {
            int urgent = (int)priority_queues.get(TaskPriority.URGENT).length;
            int high = (int)priority_queues.get(TaskPriority.HIGH).length;
            int normal = (int)priority_queues.get(TaskPriority.NORMAL).length;
            int low = (int)priority_queues.get(TaskPriority.LOW).length;
            
            return new TaskStats(urgent, high, normal, low, current_operations);
        }
    }
    
    /**
     * Interface for executable tasks
     */
    public interface TaskExecutor : Object {
        public abstract async void execute(Cancellable? cancellable = null) throws Error;
        public abstract void cancel();
    }
    
    /**
     * Wrapper for queued tasks
     */
    public class QueuedTask {
        public string id { get; private set; }
        public TaskExecutor executor { get; private set; }
        public TaskPriority priority { get; private set; }
        public string? description { get; private set; }
        public DateTime queued_at { get; private set; }
        
        private Cancellable cancellable;
        
        public QueuedTask(TaskExecutor executor, TaskPriority priority, string? description = null) {
            this.id = generate_task_id();
            this.executor = executor;
            this.priority = priority;
            this.description = description;
            this.queued_at = new DateTime.now_local();
            this.cancellable = new Cancellable();
        }
        
        public async void execute() throws Error {
            yield executor.execute(cancellable);
        }
        
        public void cancel() {
            cancellable.cancel();
            executor.cancel();
        }
        
        private string generate_task_id() {
            // Simple ID generation using timestamp
            return "task_" + get_monotonic_time().to_string();
        }
    }
    
    /**
     * Task queue statistics
     */
    public class TaskStats {
        public int urgent_count { get; private set; }
        public int high_count { get; private set; }
        public int normal_count { get; private set; }
        public int low_count { get; private set; }
        public int active_count { get; private set; }
        
        public int total_pending { 
            get { return urgent_count + high_count + normal_count + low_count; }
        }
        
        public TaskStats(int urgent, int high, int normal, int low, int active) {
            this.urgent_count = urgent;
            this.high_count = high;
            this.normal_count = normal;
            this.low_count = low;
            this.active_count = active;
        }
    }
}