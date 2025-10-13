/*
 * Copyright (C) 2024 SSHer
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

namespace KeyMaker {
    public class KeySelectionManager : Object {
        private GenericArray<SSHKey> _available_keys;
        private GenericArray<SSHKey> _selected_keys;
        
        public signal void keys_changed ();
        public signal void selection_changed ();
        
        public KeySelectionManager () {
            _available_keys = new GenericArray<SSHKey> ();
            _selected_keys = new GenericArray<SSHKey> ();
        }
        
        public GenericArray<SSHKey> get_available_keys () {
            return _available_keys;
        }
        
        public GenericArray<SSHKey> get_selected_keys () {
            return _selected_keys;
        }
        
        public void set_available_keys (GenericArray<SSHKey> keys) {
            print ("KeySelectionManager: Setting available keys, count: %u\n", keys.length);
            _available_keys = keys;
            keys_changed ();
        }
        
        public void add_available_key (SSHKey key) {
            print ("KeySelectionManager: Adding available key: %s\n", key.get_display_name ());
            _available_keys.add (key);
            keys_changed ();
        }
        
        public void clear_available_keys () {
            print ("KeySelectionManager: Clearing available keys\n");
            _available_keys.remove_range (0, _available_keys.length);
            keys_changed ();
        }
        
        public void select_key (SSHKey key) {
            if (!is_key_selected (key)) {
                print ("KeySelectionManager: Selecting key: %s\n", key.get_display_name ());
                _selected_keys.add (key);
                selection_changed ();
            }
        }
        
        public void deselect_key (SSHKey key) {
            for (uint i = 0; i < _selected_keys.length; i++) {
                if (_selected_keys[i] == key) {
                    print ("KeySelectionManager: Deselecting key: %s\n", key.get_display_name ());
                    _selected_keys.remove_index (i);
                    selection_changed ();
                    break;
                }
            }
        }
        
        public bool is_key_selected (SSHKey key) {
            for (uint i = 0; i < _selected_keys.length; i++) {
                if (_selected_keys[i] == key) {
                    return true;
                }
            }
            return false;
        }
        
        public void clear_selection () {
            print ("KeySelectionManager: Clearing selection\n");
            _selected_keys.remove_range (0, _selected_keys.length);
            selection_changed ();
        }
        
        public void select_all () {
            print ("KeySelectionManager: Selecting all keys\n");
            _selected_keys.remove_range (0, _selected_keys.length);
            for (uint i = 0; i < _available_keys.length; i++) {
                _selected_keys.add (_available_keys[i]);
            }
            selection_changed ();
        }
        
        public uint get_available_count () {
            return _available_keys.length;
        }
        
        public uint get_selected_count () {
            return _selected_keys.length;
        }
    }
}