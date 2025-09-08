/*
 * Key Maker - Page Models
 * 
 * Copyright (C) 2025 Thiago Fernandes
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

namespace KeyMaker {
    
    // Diagnostic models
    public enum DiagnosticTestType {
        QUICK,
        DETAILED
    }
    
    public enum DiagnosticStatus {
        SUCCESS,
        WARNING,
        ERROR
    }
    
    public class DiagnosticTest : GLib.Object {
        public string name { get; set; }
        public string description { get; set; }
        public DiagnosticTestType test_type { get; set; }
    }
    
    // SSHTunnel and SSHTunnelConfig should be defined elsewhere
    // DiagnosticResult should be defined elsewhere
    // RotationPlan should be defined elsewhere
    
    public class RollbackEntry : GLib.Object {
        public string plan_name { get; set; }
        public DateTime executed_at { get; set; }
        public DateTime expiry_date { get; set; }
        public string backup_path { get; set; }
    }
}