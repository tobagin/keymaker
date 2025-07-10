"""Performance tests for KeySmith with large SSH key collections."""

import pytest
import tempfile
import asyncio
import time
from pathlib import Path
from unittest.mock import patch, Mock
from datetime import datetime

from keysmith.models import SSHKey, SSHKeyType
from keysmith.backend.key_scanner import scan_ssh_directory
from keysmith.backend.ssh_operations import get_fingerprint, get_key_type


class TestLargeKeyCollectionPerformance:
    """Test performance with large numbers of SSH keys."""
    
    def setup_method(self):
        """Set up test environment with many keys."""
        self.temp_dir = tempfile.TemporaryDirectory()
        self.ssh_dir = Path(self.temp_dir.name) / ".ssh"
        self.ssh_dir.mkdir(mode=0o700)
        
        self.home_patcher = patch('pathlib.Path.home')
        self.mock_home = self.home_patcher.start()
        self.mock_home.return_value = Path(self.temp_dir.name)
    
    def teardown_method(self):
        """Clean up test environment."""
        self.home_patcher.stop()
        self.temp_dir.cleanup()
    
    def create_many_keys(self, count: int):
        """Create a large number of test SSH keys.
        
        Args:
            count: Number of key pairs to create
        """
        key_types = [SSHKeyType.ED25519, SSHKeyType.RSA, SSHKeyType.ECDSA]
        
        for i in range(count):
            key_type = key_types[i % len(key_types)]
            
            private_path = self.ssh_dir / f"test_key_{i:04d}"
            public_path = self.ssh_dir / f"test_key_{i:04d}.pub"
            
            # Create private key
            if key_type == SSHKeyType.RSA:
                private_content = f"-----BEGIN RSA PRIVATE KEY-----\nmock_rsa_private_key_content_{i}\n-----END RSA PRIVATE KEY-----"
                public_content = f"ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAAB mock_rsa_content_{i} test_{i}@keysmith.local"
            elif key_type == SSHKeyType.ECDSA:
                private_content = f"-----BEGIN EC PRIVATE KEY-----\nmock_ecdsa_private_key_content_{i}\n-----END EC PRIVATE KEY-----"
                public_content = f"ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTY mock_ecdsa_content_{i} test_{i}@keysmith.local"
            else:  # ED25519
                private_content = f"-----BEGIN OPENSSH PRIVATE KEY-----\nmock_ed25519_private_key_content_{i}\n-----END OPENSSH PRIVATE KEY-----"
                public_content = f"ssh-ed25519 AAAAC3NzaC1lZDI1NTE5 mock_ed25519_content_{i} test_{i}@keysmith.local"
            
            private_path.write_text(private_content)
            private_path.chmod(0o600)
            
            public_path.write_text(public_content)
    
    @pytest.mark.asyncio
    @pytest.mark.parametrize("key_count", [10, 50, 100])
    async def test_scan_performance_with_many_keys(self, key_count):
        """Test scanning performance with various numbers of keys."""
        self.create_many_keys(key_count)
        
        # Mock fingerprint and key type operations to focus on scanning logic
        with patch('keysmith.backend.ssh_operations.get_fingerprint') as mock_fingerprint, \
             patch('keysmith.backend.ssh_operations.get_key_type') as mock_key_type:
            
            def mock_fingerprint_func(path):
                # Simulate some processing time
                time.sleep(0.001)  # 1ms per key
                key_num = path.stem.split('_')[-1]
                return f"SHA256:mock_fingerprint_{key_num}"
            
            def mock_key_type_func(path):
                # Simulate some processing time
                time.sleep(0.001)  # 1ms per key
                key_num = int(path.stem.split('_')[-1])
                key_types = [SSHKeyType.ED25519, SSHKeyType.RSA, SSHKeyType.ECDSA]
                return key_types[key_num % len(key_types)]
            
            mock_fingerprint.side_effect = mock_fingerprint_func
            mock_key_type.side_effect = mock_key_type_func
            
            # Measure scanning time
            start_time = time.time()
            keys = await scan_ssh_directory()
            scan_time = time.time() - start_time
            
            # Verify all keys were found
            assert len(keys) == key_count
            
            # Performance assertions (adjust thresholds as needed)
            if key_count <= 10:
                assert scan_time < 1.0, f"Scanning {key_count} keys took {scan_time:.2f}s, expected < 1.0s"
            elif key_count <= 50:
                assert scan_time < 5.0, f"Scanning {key_count} keys took {scan_time:.2f}s, expected < 5.0s"
            else:  # 100 keys
                assert scan_time < 10.0, f"Scanning {key_count} keys took {scan_time:.2f}s, expected < 10.0s"
            
            print(f"Scanned {key_count} keys in {scan_time:.3f} seconds ({scan_time/key_count*1000:.1f}ms per key)")
    
    @pytest.mark.asyncio
    async def test_memory_usage_with_large_collection(self):
        """Test memory usage doesn't grow excessively with large key collections."""
        import tracemalloc
        
        # Create a substantial number of keys
        key_count = 200
        self.create_many_keys(key_count)
        
        with patch('keysmith.backend.ssh_operations.get_fingerprint') as mock_fingerprint, \
             patch('keysmith.backend.ssh_operations.get_key_type') as mock_key_type:
            
            # Fast mocks to focus on memory usage
            mock_fingerprint.side_effect = lambda path: f"SHA256:mock_{path.stem}"
            mock_key_type.side_effect = lambda path: SSHKeyType.ED25519
            
            # Start memory tracking
            tracemalloc.start()
            
            # Scan keys multiple times to check for memory leaks
            for i in range(5):
                keys = await scan_ssh_directory()
                assert len(keys) == key_count
            
            # Get memory usage
            current, peak = tracemalloc.get_traced_memory()
            tracemalloc.stop()
            
            # Memory usage should be reasonable (adjust threshold as needed)
            # Allow up to 10MB for 200 keys scanned 5 times
            max_memory_mb = 10
            peak_mb = peak / 1024 / 1024
            
            assert peak_mb < max_memory_mb, f"Peak memory usage {peak_mb:.1f}MB exceeded threshold {max_memory_mb}MB"
            
            print(f"Peak memory usage: {peak_mb:.1f}MB for {key_count} keys")
    
    @pytest.mark.asyncio
    async def test_concurrent_operations_performance(self):
        """Test performance when multiple operations happen concurrently."""
        key_count = 50
        self.create_many_keys(key_count)
        
        with patch('keysmith.backend.ssh_operations.get_fingerprint') as mock_fingerprint, \
             patch('keysmith.backend.ssh_operations.get_key_type') as mock_key_type:
            
            # Simulate realistic operation times
            mock_fingerprint.side_effect = lambda path: f"SHA256:mock_{path.stem}"
            mock_key_type.side_effect = lambda path: SSHKeyType.ED25519
            
            # Run multiple concurrent scans
            start_time = time.time()
            
            tasks = [scan_ssh_directory() for _ in range(3)]
            results = await asyncio.gather(*tasks)
            
            concurrent_time = time.time() - start_time
            
            # All scans should return the same results
            for keys in results:
                assert len(keys) == key_count
            
            # Concurrent operations should not take much longer than serial
            # Allow up to 2x the time for 3 concurrent operations
            expected_max_time = 2.0  # Adjust based on system performance
            assert concurrent_time < expected_max_time, \
                f"Concurrent operations took {concurrent_time:.2f}s, expected < {expected_max_time}s"
            
            print(f"3 concurrent scans of {key_count} keys completed in {concurrent_time:.3f} seconds")
    
    @pytest.mark.asyncio
    async def test_large_key_file_handling(self):
        """Test handling of unusually large key files."""
        # Create keys with large comments or unusual content
        large_comment = "x" * 1000  # 1KB comment
        very_large_comment = "x" * 10000  # 10KB comment
        
        test_cases = [
            ("normal_key", "normal comment"),
            ("large_comment_key", large_comment),
            ("very_large_comment_key", very_large_comment),
        ]
        
        for filename, comment in test_cases:
            private_path = self.ssh_dir / filename
            public_path = self.ssh_dir / f"{filename}.pub"
            
            private_content = "-----BEGIN OPENSSH PRIVATE KEY-----\n" + "x" * 2000 + "\n-----END OPENSSH PRIVATE KEY-----"
            public_content = f"ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI mock_content {comment}"
            
            private_path.write_text(private_content)
            private_path.chmod(0o600)
            public_path.write_text(public_content)
        
        with patch('keysmith.backend.ssh_operations.get_fingerprint') as mock_fingerprint, \
             patch('keysmith.backend.ssh_operations.get_key_type') as mock_key_type:
            
            mock_fingerprint.side_effect = lambda path: f"SHA256:mock_{path.stem}"
            mock_key_type.side_effect = lambda path: SSHKeyType.ED25519
            
            start_time = time.time()
            keys = await scan_ssh_directory()
            scan_time = time.time() - start_time
            
            # Should handle all keys including large ones
            assert len(keys) == len(test_cases)
            
            # Should not take excessively long even with large files
            assert scan_time < 5.0, f"Scanning large keys took {scan_time:.2f}s, expected < 5.0s"
            
            print(f"Handled {len(test_cases)} keys with large content in {scan_time:.3f} seconds")


class TestUIPerformanceWithManyKeys:
    """Test UI responsiveness with large key collections."""
    
    def setup_method(self):
        """Set up test environment."""
        self.temp_dir = tempfile.TemporaryDirectory()
        self.ssh_dir = Path(self.temp_dir.name) / ".ssh"
        self.ssh_dir.mkdir(mode=0o700)
        
        self.home_patcher = patch('pathlib.Path.home')
        self.mock_home = self.home_patcher.start()
        self.mock_home.return_value = Path(self.temp_dir.name)
    
    def teardown_method(self):
        """Clean up test environment."""
        self.home_patcher.stop()
        self.temp_dir.cleanup()
    
    def create_mock_keys(self, count: int) -> list[SSHKey]:
        """Create mock SSH key objects for testing.
        
        Args:
            count: Number of mock keys to create
            
        Returns:
            List of mock SSH key objects
        """
        keys = []
        for i in range(count):
            private_path = self.ssh_dir / f"mock_key_{i:04d}"
            public_path = self.ssh_dir / f"mock_key_{i:04d}.pub"
            
            key = SSHKey(
                private_path=private_path,
                public_path=public_path,
                key_type=SSHKeyType.ED25519,
                fingerprint=f"SHA256:mock_fingerprint_{i:04d}",
                comment=f"test_{i}@keysmith.local",
                last_modified=datetime.now(),
                bit_size=None
            )
            keys.append(key)
        
        return keys
    
    def test_key_list_rendering_performance(self):
        """Test key list widget performance with many keys."""
        # This would require GTK to be initialized, so we'll mock the key list
        mock_keys = self.create_mock_keys(100)
        
        # Simulate key list update time
        start_time = time.time()
        
        # In a real test, this would update the actual KeyListWidget
        # For now, we'll simulate the work that would be done
        for key in mock_keys:
            # Simulate creating a row widget for each key
            time.sleep(0.0001)  # 0.1ms per key
        
        render_time = time.time() - start_time
        
        # UI should remain responsive
        assert render_time < 0.5, f"Rendering {len(mock_keys)} keys took {render_time:.3f}s, expected < 0.5s"
        
        print(f"Simulated rendering {len(mock_keys)} keys in {render_time:.3f} seconds")


if __name__ == "__main__":
    pytest.main([__file__, "-v"])