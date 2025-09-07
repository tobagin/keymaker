/*
 * Key Maker - Batch Processor
 * 
 * Simple utility for collecting items into batches for efficient processing.
 */

namespace KeyMaker {
    
    /**
     * Simple batch collector - collects items and emits batches when ready
     */
    public class BatchProcessor : Object {
        
        public signal void batch_ready(GenericArray<Object> batch);
        
        private GenericArray<Object> pending_items;
        private uint batch_size;
        private uint delay_ms;
        private uint timeout_id;
        
        public BatchProcessor(uint batch_size = 10, uint delay_ms = 100) {
            this.batch_size = batch_size;
            this.delay_ms = delay_ms;
            this.pending_items = new GenericArray<Object>();
        }
        
        /**
         * Add an item to the batch
         */
        public void add_item(Object item) {
            pending_items.add(item);
            
            // Cancel existing timeout
            if (timeout_id > 0) {
                Source.remove(timeout_id);
            }
            
            // Process immediately if batch is full, otherwise schedule
            if (pending_items.length >= batch_size) {
                emit_batch();
            } else {
                timeout_id = Timeout.add(delay_ms, () => {
                    emit_batch();
                    timeout_id = 0;
                    return Source.REMOVE;
                });
            }
        }
        
        /**
         * Add multiple items at once
         */
        public void add_items(GenericArray<Object> items) {
            for (int i = 0; i < items.length; i++) {
                pending_items.add(items[i]);
            }
            
            // Cancel existing timeout and emit immediately
            if (timeout_id > 0) {
                Source.remove(timeout_id);
                timeout_id = 0;
            }
            
            emit_batch();
        }
        
        /**
         * Force processing of any remaining items
         */
        public void flush() {
            if (timeout_id > 0) {
                Source.remove(timeout_id);
                timeout_id = 0;
            }
            
            if (pending_items.length > 0) {
                emit_batch();
            }
        }
        
        /**
         * Clear all pending items
         */
        public void clear() {
            if (timeout_id > 0) {
                Source.remove(timeout_id);
                timeout_id = 0;
            }
            
            pending_items.remove_range(0, pending_items.length);
        }
        
        /**
         * Get current pending count
         */
        public uint get_pending_count() {
            return pending_items.length;
        }
        
        /**
         * Emit the current batch
         */
        private void emit_batch() {
            if (pending_items.length == 0) {
                return;
            }
            
            // Create a copy of current items and emit
            var batch = new GenericArray<Object>();
            for (int i = 0; i < pending_items.length; i++) {
                batch.add(pending_items[i]);
            }
            
            // Clear pending items
            pending_items.remove_range(0, pending_items.length);
            
            // Emit the batch
            batch_ready(batch);
            
            KeyMaker.Log.debug("BATCH_PROCESSOR", "Emitted batch of %u items", batch.length);
        }
    }
}