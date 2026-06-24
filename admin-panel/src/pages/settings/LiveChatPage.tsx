import { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { MessageCircle, Copy, Check } from 'lucide-react';
import { PageWrapper } from '../../components/layout/PageWrapper';
import { Card } from '../../components/ui/Card';
import { Button } from '../../components/ui/Button';
import { Input } from '../../components/ui/Input';
import { useToast } from '../../components/ui/Toast';
import { getApiErrorMessage } from '../../api';

interface LiveChatSettings {
  live_chat_enabled: boolean;
  tawk_widget_id: string | null;
}

export default function LiveChatPage() {
  const qc = useQueryClient();
  const { toast } = useToast();
  const [copied, setCopied] = useState(false);

  const [formData, setFormData] = useState<LiveChatSettings>({
    live_chat_enabled: false,
    tawk_widget_id: '',
  });

  // Fetch live chat settings
  const { data: settings, isLoading } = useQuery({
    queryKey: ['live-chat-settings'],
    queryFn: async () => {
      const response = await fetch('/admin/live-chat/settings', {
        method: 'GET',
        headers: {
          'Authorization': `Bearer ${localStorage.getItem('admin_token')}`,
          'Content-Type': 'application/json',
        },
      });

      if (!response.ok) throw new Error('Failed to fetch settings');
      const data = await response.json();
      return data.data as LiveChatSettings;
    },
  });

  // Update live chat settings mutation
  const updateMutation = useMutation({
    mutationFn: async (data: LiveChatSettings) => {
      const response = await fetch('/admin/live-chat/settings', {
        method: 'PUT',
        headers: {
          'Authorization': `Bearer ${localStorage.getItem('admin_token')}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(data),
      });

      if (!response.ok) throw new Error('Failed to update settings');
      return response.json();
    },
    onSuccess: () => {
      toast('Live chat settings updated successfully', 'success');
      qc.invalidateQueries({ queryKey: ['live-chat-settings'] });
    },
    onError: (e: unknown) => toast(getApiErrorMessage(e), 'error'),
  });

  // Initialize form when data loads
  useState(() => {
    if (settings) {
      setFormData(settings);
    }
  });

  const handleToggle = () => {
    setFormData(prev => ({
      ...prev,
      live_chat_enabled: !prev.live_chat_enabled,
    }));
  };

  const handleWidgetIdChange = (value: string) => {
    setFormData(prev => ({
      ...prev,
      tawk_widget_id: value,
    }));
  };

  const handleSave = () => {
    if (formData.live_chat_enabled && !formData.tawk_widget_id?.trim()) {
      toast('Tawk widget ID is required when live chat is enabled', 'error');
      return;
    }
    updateMutation.mutate(formData);
  };

  const copyToClipboard = () => {
    if (formData.tawk_widget_id) {
      navigator.clipboard.writeText(formData.tawk_widget_id);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
      toast('Widget ID copied to clipboard', 'success');
    }
  };

  return (
    <PageWrapper title="Live Chat Settings">
      {isLoading ? (
        <Card className="p-8 flex justify-center">
          <div className="animate-spin w-8 h-8 border-2 border-blue-200 border-t-blue-600 rounded-full" />
        </Card>
      ) : (
        <div className="space-y-6">
          {/* Info Card */}
          <Card className="p-6 bg-blue-50 border border-blue-200">
            <div className="flex gap-4">
              <MessageCircle className="text-blue-600 flex-shrink-0" size={24} />
              <div className="space-y-2">
                <h3 className="font-semibold text-blue-900">Live Chat Support</h3>
                <p className="text-sm text-blue-800">
                  Enable Tawk.to live chat widget for your customers and drivers. They can access it from the menu/sidedrawer and help page.
                </p>
                <a
                  href="https://www.tawk.to"
                  target="_blank"
                  rel="noopener noreferrer"
                  className="text-sm text-blue-600 hover:underline inline-block mt-2"
                >
                  Get your Tawk widget →
                </a>
              </div>
            </div>
          </Card>

          {/* Settings Card */}
          <Card className="p-6 space-y-6">
            <div>
              <h2 className="text-lg font-semibold text-slate-900 mb-6">Configuration</h2>

              {/* Enable/Disable Toggle */}
              <div className="flex items-center justify-between p-4 rounded-lg border border-slate-200 bg-slate-50">
                <div>
                  <p className="font-medium text-slate-900">Enable Live Chat</p>
                  <p className="text-sm text-slate-600 mt-1">
                    Enable Tawk.to live chat widget for your apps
                  </p>
                </div>
                <button
                  onClick={handleToggle}
                  className={`relative inline-flex h-8 w-14 items-center rounded-full transition-colors ${
                    formData.live_chat_enabled
                      ? 'bg-blue-600'
                      : 'bg-slate-300'
                  }`}
                >
                  <span
                    className={`inline-block h-6 w-6 transform rounded-full bg-white transition-transform ${
                      formData.live_chat_enabled ? 'translate-x-7' : 'translate-x-1'
                    }`}
                  />
                </button>
              </div>

              {/* Widget ID Input */}
              {formData.live_chat_enabled && (
                <div className="mt-6 space-y-3">
                  <label className="block">
                    <span className="text-sm font-medium text-slate-700">Tawk Widget ID</span>
                    <p className="text-xs text-slate-500 mt-1">
                      Found in your Tawk.to dashboard under Admin → Property → Code
                    </p>
                  </label>
                  <div className="flex gap-2">
                    <Input
                      type="text"
                      placeholder="e.g., 1234567890abc"
                      value={formData.tawk_widget_id || ''}
                      onChange={(e) => handleWidgetIdChange(e.target.value)}
                      className="flex-1"
                    />
                    <button
                      onClick={copyToClipboard}
                      disabled={!formData.tawk_widget_id}
                      className="px-4 py-2 rounded-lg border border-slate-300 hover:bg-slate-50 transition-colors disabled:opacity-50 disabled:cursor-not-allowed flex items-center gap-2"
                    >
                      {copied ? (
                        <Check size={18} className="text-green-600" />
                      ) : (
                        <Copy size={18} />
                      )}
                    </button>
                  </div>
                </div>
              )}
            </div>

            {/* Info */}
            {formData.live_chat_enabled && formData.tawk_widget_id && (
              <div className="p-4 rounded-lg bg-green-50 border border-green-200">
                <p className="text-sm text-green-900">
                  ✓ Live chat widget will appear in the menu/sidedrawer and help page for both customer and driver apps
                </p>
              </div>
            )}

            {formData.live_chat_enabled && !formData.tawk_widget_id && (
              <div className="p-4 rounded-lg bg-yellow-50 border border-yellow-200">
                <p className="text-sm text-yellow-900">
                  ⚠ Please enter your Tawk widget ID to enable live chat
                </p>
              </div>
            )}

            {!formData.live_chat_enabled && (
              <div className="p-4 rounded-lg bg-slate-50 border border-slate-200">
                <p className="text-sm text-slate-700">
                  Live chat is currently disabled. Enable it above to add Tawk support to your apps.
                </p>
              </div>
            )}
          </Card>

          {/* Save Button */}
          <div className="flex gap-3">
            <Button
              onClick={handleSave}
              loading={updateMutation.isPending}
              className="flex-1"
            >
              Save Settings
            </Button>
          </div>

          {/* Setup Instructions */}
          <Card className="p-6 space-y-4">
            <h3 className="font-semibold text-slate-900 flex items-center gap-2">
              <MessageCircle size={18} />
              How to Set Up
            </h3>
            <ol className="space-y-3 text-sm text-slate-700 list-decimal list-inside">
              <li>Visit <a href="https://www.tawk.to" target="_blank" rel="noopener noreferrer" className="text-blue-600 hover:underline">tawk.to</a> and create an account</li>
              <li>Create a new property for your app</li>
              <li>Go to Admin → Property → Code</li>
              <li>Copy your Widget ID (format: xxxxx/yyyyyy)</li>
              <li>Paste it in the "Tawk Widget ID" field above</li>
              <li>Click "Save Settings"</li>
              <li>The live chat widget will appear in your apps immediately</li>
            </ol>
          </Card>

          {/* API Info */}
          <Card className="p-6 bg-slate-50 space-y-4">
            <h3 className="font-semibold text-slate-900">API Endpoints</h3>
            <div className="space-y-3 text-sm font-mono text-slate-700 bg-white p-3 rounded border border-slate-200">
              <div>
                <p className="text-slate-600 text-xs font-normal mb-1">Public - Get Settings</p>
                <p>GET /live-chat/settings</p>
              </div>
              <div className="border-t border-slate-200 pt-3">
                <p className="text-slate-600 text-xs font-normal mb-1">Admin Only - Update Settings</p>
                <p>PUT /admin/live-chat/settings</p>
              </div>
            </div>
          </Card>
        </div>
      )}
    </PageWrapper>
  );
}
