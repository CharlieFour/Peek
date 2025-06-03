import React, { useEffect, useState } from "react";
import { createClient } from "@supabase/supabase-js";
import { Card, CardContent } from "@/components/ui/card";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Badge } from "@/components/ui/badge";

const supabase = createClient("https://YOUR_SUPABASE_URL", "YOUR_SUPABASE_ANON_KEY");

export default function ActivityLoggerDashboard() {
  const [devices, setDevices] = useState([]);
  const [keyLogs, setKeyLogs] = useState([]);
  const [activityLogs, setActivityLogs] = useState([]);
  const [selectedDevice, setSelectedDevice] = useState(null);

  useEffect(() => {
    const fetchDevices = async () => {
      const { data } = await supabase.from("devices").select("*").order("last_seen", { ascending: false });
      setDevices(data);
    };
    fetchDevices();
  }, []);

  useEffect(() => {
    if (!selectedDevice) return;
    const fetchLogs = async () => {
      const { data: keys } = await supabase.from("key_logs").select("*").eq("device_id", selectedDevice).order("timestamp", { ascending: false }).limit(100);
      const { data: activities } = await supabase.from("activity_logs").select("*").eq("device_id", selectedDevice).order("timestamp", { ascending: false }).limit(100);
      setKeyLogs(keys);
      setActivityLogs(activities);
    };
    fetchLogs();
  }, [selectedDevice]);

  return (
    <div className="p-4 space-y-6">
      <h1 className="text-3xl font-bold text-center">🔍 Activity Logger Dashboard</h1>
      <p className="text-center text-gray-600">Monitor devices in real-time — key strokes and app usage</p>

      <h2 className="text-xl font-semibold mt-6">Connected Devices</h2>
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
        {devices.map((device) => (
          <Card
            key={device.id}
            className={`cursor-pointer transition-all duration-200 hover:shadow-xl ${selectedDevice === device.id ? "ring-2 ring-blue-500" : ""}`}
            onClick={() => setSelectedDevice(device.id)}
          >
            <CardContent className="p-4">
              <p className="font-semibold text-lg">🖥 {device.hostname}</p>
              <p className="text-sm text-gray-600">📍 IP: {device.ip_address}</p>
              <p className="text-sm text-gray-600">🛠 OS: {device.os}</p>
              <p className="text-xs text-gray-500">⏱ Last Seen: {new Date(device.last_seen).toLocaleString()}</p>
            </CardContent>
          </Card>
        ))}
      </div>

      {selectedDevice && (
        <Tabs defaultValue="keys" className="mt-6">
          <TabsList className="flex justify-center mb-4">
            <TabsTrigger value="keys">📝 Key Logs</TabsTrigger>
            <TabsTrigger value="activities">📊 Activity Logs</TabsTrigger>
          </TabsList>

          <TabsContent value="keys">
            <div className="space-y-3">
              {keyLogs.map((log) => (
                <div key={log.id} className="border border-gray-200 p-3 rounded-lg shadow-sm bg-white">
                  <Badge className="mb-1">{log.app_name}</Badge>
                  <p className="text-sm">💬 <strong>Keystroke:</strong> {log.keystroke}</p>
                  <p className="text-xs text-gray-500">🕒 {new Date(log.timestamp).toLocaleString()}</p>
                </div>
              ))}
            </div>
          </TabsContent>

          <TabsContent value="activities">
            <div className="space-y-3">
              {activityLogs.map((log) => (
                <div key={log.id} className="border border-gray-200 p-3 rounded-lg shadow-sm bg-white">
                  <Badge className="mb-1">{log.process_name}</Badge>
                  <p className="text-sm">📂 <strong>Window:</strong> {log.window_title}</p>
                  <p className="text-xs text-gray-500">🕒 {new Date(log.timestamp).toLocaleString()}</p>
                </div>
              ))}
            </div>
          </TabsContent>
        </Tabs>
      )}
    </div>
  );
}