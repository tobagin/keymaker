/*
 * Key Maker - SSH Operations Backend (Facade)
 * 
 * Main facade for SSH operations, delegates to specialized modules.
 * 
 * Copyright (C) 2025 Thiago Fernandes
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

namespace KeyMaker {
    
    public class SSHOperations {
        
        // Generation operations (delegate to SSHGeneration)
        public static async SSHKey generate_key (KeyGenerationRequest request) throws KeyMakerError {
            return yield SSHGeneration.generate_key(request);
        }
        
        // Metadata operations (delegate to SSHMetadata)
        public static async string get_fingerprint (File key_path) throws KeyMakerError {
            return yield SSHMetadata.get_fingerprint(key_path);
        }
        
        public static string get_fingerprint_sync (File key_path) throws KeyMakerError {
            return SSHMetadata.get_fingerprint_sync(key_path);
        }
        
        public static async string get_fingerprint_with_cancellable (File key_path, Cancellable? cancellable) throws KeyMakerError {
            try {
                return yield SSHMetadata.get_fingerprint_with_cancellable(key_path, cancellable);
            } catch (IOError.CANCELLED e) {
                throw new KeyMakerError.OPERATION_CANCELLED ("Operation was cancelled");
            }
        }
        
        public static async SSHKeyType get_key_type (File key_path) throws KeyMakerError {
            return yield SSHMetadata.get_key_type(key_path);
        }
        
        public static SSHKeyType get_key_type_sync (File key_path) throws KeyMakerError {
            return SSHMetadata.get_key_type_sync(key_path);
        }
        
        public static async SSHKeyType get_key_type_with_cancellable (File key_path, Cancellable? cancellable) throws KeyMakerError {
            try {
                return yield SSHMetadata.get_key_type_with_cancellable(key_path, cancellable);
            } catch (IOError.CANCELLED e) {
                throw new KeyMakerError.OPERATION_CANCELLED ("Operation was cancelled");
            }
        }
        
        public static async int? extract_bit_size (File key_path) throws KeyMakerError {
            return yield SSHMetadata.extract_bit_size(key_path);
        }
        
        public static int? extract_bit_size_sync (File key_path) throws KeyMakerError {
            return SSHMetadata.extract_bit_size_sync(key_path);
        }
        
        public static async int? extract_bit_size_with_cancellable (File key_path, Cancellable? cancellable) throws KeyMakerError {
            return yield SSHMetadata.extract_bit_size_with_cancellable(key_path, cancellable);
        }
        
        public static string get_public_key_content (SSHKey ssh_key) throws KeyMakerError {
            return SSHMetadata.get_public_key_content(ssh_key);
        }
        
        // Mutation operations (delegate to SSHMutate)
        public static async void change_passphrase (PassphraseChangeRequest request) throws KeyMakerError {
            yield SSHMutate.change_passphrase(request);
        }
        
        public static async void delete_key_pair (SSHKey ssh_key) throws KeyMakerError {
            yield SSHMutate.delete_key_pair(ssh_key);
        }
    }
}