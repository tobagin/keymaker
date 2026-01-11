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