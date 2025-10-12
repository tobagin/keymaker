/*
 * Key Maker - SSH Key Management Application
 * 
 * A GTK4/Libadwaita application for managing SSH keys with an intuitive GUI.
 * 
 * Copyright (C) 2025 Thiago Fernandes
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

int main (string[] args) {
    var app = new KeyMaker.Application ();
    return app.run (args);
}