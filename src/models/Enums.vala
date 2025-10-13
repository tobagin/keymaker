/*
 * SSHer - Data Model Enums
 * 
 * Copyright (C) 2025 Thiago Fernandes
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

namespace KeyMaker {
    
    /**
     * Supported SSH key types
     */
    public enum SSHKeyType {
        ED25519,
        RSA,
        ECDSA; // Listed but not recommended
        
        public string to_string () {
            switch (this) {
                case ED25519:
                    return "ed25519";
                case RSA:
                    return "rsa";
                case ECDSA:
                    return "ecdsa";
                default:
                    assert_not_reached ();
            }
        }
        
        public string get_icon_name () {
            switch (this) {
                case ED25519:
                    return "security-high-symbolic";
                case RSA:
                    return "security-medium-symbolic";
                case ECDSA:
                    return "security-low-symbolic";
                default:
                    assert_not_reached ();
            }
        }
        
        public static SSHKeyType from_string (string type_str) throws KeyMakerError {
            switch (type_str.down ()) {
                case "ed25519":
                    return ED25519;
                case "rsa":
                    return RSA;
                case "ecdsa":
                    return ECDSA;
                default:
                    throw new KeyMakerError.INVALID_KEY_TYPE ("Unknown key type: %s", type_str);
            }
        }
    }
    
    public enum RotationPlanStatus {
        DRAFT,          // Plan created but not executed
        SCHEDULED,      // Plan scheduled for execution
        RUNNING,        // Currently executing
        COMPLETED,      // Successfully completed
        FAILED,         // Failed during execution
        CANCELLED,      // Cancelled by user
        ROLLED_BACK;    // Successfully rolled back
        
        public string to_string () {
            switch (this) {
                case DRAFT: return "Draft";
                case SCHEDULED: return "Scheduled";
                case RUNNING: return "Running";
                case COMPLETED: return "Completed";
                case FAILED: return "Failed";
                case CANCELLED: return "Cancelled";
                case ROLLED_BACK: return "Rolled Back";
                default: return "Unknown";
            }
        }
        
        public string get_icon_name () {
            switch (this) {
                case DRAFT: return "x-office-address-book-symbolic";
                case SCHEDULED: return "alarm-symbolic";
                case RUNNING: return "system-run-symbolic";
                case COMPLETED: return "emblem-ok-symbolic";
                case FAILED: return "dialog-error-symbolic";
                case CANCELLED: return "process-stop-symbolic";
                case ROLLED_BACK: return "io.github.tobagin.keysmith-rollback-symbolic";
                default: return "help-about-symbolic";
            }
        }
    }
    
    public enum RollbackPeriod {
        ONE_WEEK,
        ONE_FORTNIGHT,
        ONE_MONTH;
        
        public string to_string () {
            switch (this) {
                case ONE_WEEK: return "1 Week";
                case ONE_FORTNIGHT: return "1 Fortnight";
                case ONE_MONTH: return "1 Month";
                default: return "Unknown";
            }
        }
        
        public int64 to_seconds () {
            switch (this) {
                case ONE_WEEK: return 7 * 24 * 60 * 60;
                case ONE_FORTNIGHT: return 14 * 24 * 60 * 60;
                case ONE_MONTH: return 30 * 24 * 60 * 60;
                default: return 7 * 24 * 60 * 60;
            }
        }
    }

    /**
     * Custom error types for SSH operations
     */
    public errordomain KeyMakerError {
        OPERATION_FAILED,
        INVALID_KEY_TYPE,
        KEY_NOT_FOUND,
        PERMISSION_DENIED,
        VALIDATION_FAILED,
        SUBPROCESS_FAILED,
        INVALID_INPUT,
        OPERATION_CANCELLED,
        ACCESS_DENIED,
        FILE_READ_ERROR,
        FILE_WRITE_ERROR,
        NOT_FOUND
    }
}