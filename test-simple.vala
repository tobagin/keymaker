/*
 * Simple test to verify Vala code compiles
 */

using GLib;

namespace KeyMaker {
    public enum SSHKeyType {
        ED25519,
        RSA,
        ECDSA;
        
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
    }
    
    public errordomain KeyMakerError {
        OPERATION_FAILED,
        INVALID_KEY_TYPE,
        KEY_NOT_FOUND,
        PERMISSION_DENIED,
        VALIDATION_FAILED,
        SUBPROCESS_FAILED
    }
    
    public class KeyGenerationRequest : Object {
        public SSHKeyType key_type { get; set; default = SSHKeyType.ED25519; }
        public string filename { get; set; }
        public string? passphrase { get; set; default = null; }
        public string? comment { get; set; default = null; }
        public int rsa_bits { get; set; default = 4096; }
        
        public KeyGenerationRequest (string filename) {
            Object (filename: filename);
        }
        
        public void validate () throws KeyMakerError {
            if (filename == null || filename.strip () == "") {
                throw new KeyMakerError.VALIDATION_FAILED ("Filename cannot be empty");
            }
        }
    }
}

int main (string[] args) {
    print ("Key Maker Vala Conversion Test\n");
    
    try {
        var request = new KeyMaker.KeyGenerationRequest ("test_key");
        request.key_type = KeyMaker.SSHKeyType.ED25519;
        request.validate ();
        
        print ("✓ Basic data models working\n");
        print ("✓ Key type: %s\n", request.key_type.to_string ());
        print ("✓ Filename: %s\n", request.filename);
        
        print ("All basic tests passed!\n");
        return 0;
    } catch (KeyMaker.KeyMakerError e) {
        print ("❌ Error: %s\n", e.message);
        return 1;
    }
}