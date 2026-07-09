import { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { Edit, ToggleRight, ToggleLeft } from 'lucide-react';
import { PageWrapper } from '../../components/layout/PageWrapper';
import { Card } from '../../components/ui/Card';
import { Badge } from '../../components/ui/Badge';
import { Button } from '../../components/ui/Button';
import { Modal } from '../../components/ui/Modal';
import { useToast } from '../../components/ui/Toast';
import { paymentGatewaysApi } from '../../api/payments';
import { getApiErrorMessage } from '../../api';
import { formatCurrency } from '../../utils';

export default function PaymentGatewaysSettings() {
  const qc = useQueryClient();
  const { toast } = useToast();

  const [editingId, setEditingId] = useState<number | null>(null);
  const [formData, setFormData] = useState<Record<string, any>>({});
  const [logoFile, setLogoFile] = useState<File | null>(null);
  const [logoPreview, setLogoPreview] = useState<string | null>(null);

  const { data: gateways = [], isLoading } = useQuery({
    queryKey: ['payment-gateways'],
    queryFn: () => paymentGatewaysApi.list(),
  });

  const { data: stats = [] } = useQuery({
    queryKey: ['payment-gateways-stats'],
    queryFn: () => paymentGatewaysApi.stats(),
  });

  const toggleMutation = useMutation({
    mutationFn: (id: number) => paymentGatewaysApi.toggle(id),
    onSuccess: () => {
      toast('Gateway status updated.', 'success');
      qc.invalidateQueries({ queryKey: ['payment-gateways'] });
    },
    onError: (e) => toast(getApiErrorMessage(e), 'error'),
  });

  const updateMutation = useMutation({
    mutationFn: async (data: { id: number; formData: Record<string, any>; logo: File | null }) => {
      if (data.logo) {
        await paymentGatewaysApi.uploadLogo(data.id, data.logo);
      }
      return paymentGatewaysApi.update(data.id, data.formData);
    },
    onSuccess: () => {
      toast('Gateway updated successfully.', 'success');
      setEditingId(null);
      setLogoFile(null);
      setLogoPreview(null);
      qc.invalidateQueries({ queryKey: ['payment-gateways'] });
      qc.invalidateQueries({ queryKey: ['payment-gateways-stats'] });
    },
    onError: (e) => toast(getApiErrorMessage(e), 'error'),
  });

  const handleEdit = (gateway: any) => {
    setEditingId(gateway.id);
    setFormData(gateway);
    setLogoFile(null);
    setLogoPreview(gateway.logo_url || null);
  };

  const handleLogoChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0] ?? null;
    setLogoFile(file);
    if (file) {
      const url = URL.createObjectURL(file);
      setLogoPreview(url);
    }
  };

  const handleSave = () => {
    updateMutation.mutate({ id: editingId!, formData, logo: logoFile });
  };

  return (
    <PageWrapper title="Payment Gateways" subtitle="Configure payment gateway settings, limits, and fees">
      {/* Statistics Cards */}
      {stats.length > 0 && (
        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4 mb-6">
          {stats.map((stat: any) => (
            <Card key={stat.name} className="p-4">
              <p className="text-sm text-slate-600 mb-1">{stat.display_name}</p>
              <p className="text-2xl font-bold text-slate-900 mb-2">{stat.total_transactions}</p>
              <p className="text-xs text-slate-500 mb-3">
                {formatCurrency(parseFloat(stat.total_amount || 0))}
              </p>
              <div className="flex gap-2">
                <Badge status="success">{stat.successful_count} ✓</Badge>
                <Badge status="error">{stat.failed_count} ✗</Badge>
              </div>
            </Card>
          ))}
        </div>
      )}

      {/* Gateways Table */}
      {isLoading ? (
        <Card className="p-12 text-center">
          <div className="inline-block h-8 w-8 animate-spin rounded-full border-4 border-slate-200 border-t-brand-600" />
        </Card>
      ) : (
        <Card padding={false}>
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead>
                <tr className="border-b border-slate-200 bg-slate-50">
                  <th className="px-4 py-3 text-left text-sm font-semibold text-slate-900 w-10">Logo</th>
                  <th className="px-4 py-3 text-left text-sm font-semibold text-slate-900">Gateway</th>
                  <th className="px-4 py-3 text-center text-sm font-semibold text-slate-900">Status</th>
                  <th className="px-4 py-3 text-right text-sm font-semibold text-slate-900">Min Amount</th>
                  <th className="px-4 py-3 text-right text-sm font-semibold text-slate-900">Max Amount</th>
                  <th className="px-4 py-3 text-right text-sm font-semibold text-slate-900">Fee %</th>
                  <th className="px-4 py-3 text-right text-sm font-semibold text-slate-900">Fixed Fee</th>
                  <th className="px-4 py-3 text-center text-sm font-semibold text-slate-900">Actions</th>
                </tr>
              </thead>
              <tbody>
                {gateways.map((gateway: any) => (
                  <tr key={gateway.id} className="border-b border-slate-100 hover:bg-slate-50">
                    <td className="px-4 py-3">
                      {gateway.logo_url ? (
                        <img src={gateway.logo_url} alt="" className="w-8 h-8 object-contain rounded" />
                      ) : (
                        <div className="w-8 h-8 rounded bg-slate-100 flex items-center justify-center text-slate-400 text-xs">—</div>
                      )}
                    </td>
                    <td className="px-4 py-3">
                      <div className="text-sm font-semibold text-slate-900">{gateway.display_name}</div>
                      <div className="text-xs text-slate-500">({gateway.name})</div>
                    </td>
                    <td className="px-4 py-3 text-center">
                      <Badge status={gateway.is_enabled ? 'success' : 'error'}>
                        {gateway.is_enabled ? 'Enabled' : 'Disabled'}
                      </Badge>
                    </td>
                    <td className="px-4 py-3 text-right text-sm text-slate-600">
                      ₦{parseFloat(gateway.min_amount).toLocaleString('en-NG')}
                    </td>
                    <td className="px-4 py-3 text-right text-sm text-slate-600">
                      ₦{parseFloat(gateway.max_amount).toLocaleString('en-NG')}
                    </td>
                    <td className="px-4 py-3 text-right text-sm text-slate-600">
                      {parseFloat(gateway.transaction_fee_percent).toFixed(2)}%
                    </td>
                    <td className="px-4 py-3 text-right text-sm text-slate-600">
                      ₦{parseFloat(gateway.transaction_fee_fixed).toLocaleString('en-NG')}
                    </td>
                    <td className="px-4 py-3 text-center">
                      <div className="flex items-center justify-center gap-2">
                        <Button
                          variant="outline"
                          size="sm"
                          onClick={() => handleEdit(gateway)}
                          disabled={updateMutation.isPending}
                        >
                          <Edit size={14} />
                        </Button>
                        <Button
                          variant={gateway.is_enabled ? 'primary' : 'outline'}
                          size="sm"
                          onClick={() => toggleMutation.mutate(gateway.id)}
                          disabled={toggleMutation.isPending}
                        >
                          {gateway.is_enabled ? <ToggleRight size={14} /> : <ToggleLeft size={14} />}
                        </Button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </Card>
      )}

      {/* Edit Modal */}
      {editingId !== null && (() => {
        const isCash = gateways.find((g: any) => g.id === editingId)?.name === 'cash';
        return (
          <Modal
            open
            onClose={() => setEditingId(null)}
            title={`Edit ${gateways.find((g: any) => g.id === editingId)?.display_name}`}
            size="md"
          >
            <div className="space-y-4">
              {isCash && (
                <div className="rounded-lg bg-blue-50 border border-blue-200 px-4 py-3 text-sm text-blue-700">
                  Cash is a built-in payment method. No API keys are required.
                  You can enable or disable it to control whether customers can pay with cash.
                </div>
              )}

              <div>
                <label className="block text-sm font-medium text-slate-700 mb-1">Display Name</label>
                <input
                  type="text"
                  value={formData.display_name || ''}
                  onChange={(e) => setFormData({ ...formData, display_name: e.target.value })}
                  className="w-full px-3 py-2 border border-slate-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-brand-500"
                />
              </div>

              <div>
                <label className="block text-sm font-medium text-slate-700 mb-1">Logo / Icon</label>
                <div className="flex items-center gap-4">
                  {logoPreview ? (
                    <img src={logoPreview} alt="logo preview" className="w-12 h-12 object-contain rounded border border-slate-200 bg-slate-50 p-1" />
                  ) : (
                    <div className="w-12 h-12 rounded border border-slate-200 bg-slate-50 flex items-center justify-center text-slate-300 text-xs">None</div>
                  )}
                  <label className="cursor-pointer px-3 py-2 border border-slate-200 rounded-lg text-sm text-slate-600 hover:bg-slate-50">
                    {logoPreview ? 'Change' : 'Upload'}
                    <input type="file" accept="image/*" className="hidden" onChange={handleLogoChange} />
                  </label>
                  {logoPreview && (
                    <button
                      type="button"
                      className="text-xs text-red-500 hover:text-red-700"
                      onClick={() => { setLogoFile(null); setLogoPreview(null); }}
                    >
                      Remove
                    </button>
                  )}
                </div>
                <p className="mt-1 text-xs text-slate-400">PNG, JPG, WebP or SVG — max 2 MB. Shown in customer app.</p>
              </div>

              {!isCash && (
                <>
                  <div>
                    <label className="block text-sm font-medium text-slate-700 mb-1">Public Key</label>
                    <input
                      type="password"
                      value={formData.public_key || ''}
                      onChange={(e) => setFormData({ ...formData, public_key: e.target.value })}
                      className="w-full px-3 py-2 border border-slate-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-brand-500"
                    />
                  </div>

                  <div>
                    <label className="block text-sm font-medium text-slate-700 mb-1">Secret Key</label>
                    <input
                      type="password"
                      value={formData.secret_key || ''}
                      onChange={(e) => setFormData({ ...formData, secret_key: e.target.value })}
                      className="w-full px-3 py-2 border border-slate-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-brand-500"
                    />
                  </div>

                  <div>
                    <label className="block text-sm font-medium text-slate-700 mb-1">Webhook Secret</label>
                    <input
                      type="password"
                      value={formData.webhook_secret || ''}
                      onChange={(e) => setFormData({ ...formData, webhook_secret: e.target.value })}
                      className="w-full px-3 py-2 border border-slate-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-brand-500"
                    />
                  </div>

                  <div className="grid grid-cols-2 gap-3">
                    <div>
                      <label className="block text-sm font-medium text-slate-700 mb-1">Min Amount (₦)</label>
                      <input
                        type="number"
                        step="0.01"
                        value={formData.min_amount || 0}
                        onChange={(e) => setFormData({ ...formData, min_amount: parseFloat(e.target.value) })}
                        className="w-full px-3 py-2 border border-slate-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-brand-500"
                      />
                    </div>
                    <div>
                      <label className="block text-sm font-medium text-slate-700 mb-1">Max Amount (₦)</label>
                      <input
                        type="number"
                        step="0.01"
                        value={formData.max_amount || 999999.99}
                        onChange={(e) => setFormData({ ...formData, max_amount: parseFloat(e.target.value) })}
                        className="w-full px-3 py-2 border border-slate-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-brand-500"
                      />
                    </div>
                  </div>

                  <div className="grid grid-cols-2 gap-3">
                    <div>
                      <label className="block text-sm font-medium text-slate-700 mb-1">Fee %</label>
                      <input
                        type="number"
                        step="0.01"
                        min="0"
                        value={formData.transaction_fee_percent || 0}
                        onChange={(e) => setFormData({ ...formData, transaction_fee_percent: parseFloat(e.target.value) })}
                        className="w-full px-3 py-2 border border-slate-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-brand-500"
                      />
                    </div>
                    <div>
                      <label className="block text-sm font-medium text-slate-700 mb-1">Fixed Fee (₦)</label>
                      <input
                        type="number"
                        step="0.01"
                        min="0"
                        value={formData.transaction_fee_fixed || 0}
                        onChange={(e) => setFormData({ ...formData, transaction_fee_fixed: parseFloat(e.target.value) })}
                        className="w-full px-3 py-2 border border-slate-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-brand-500"
                      />
                    </div>
                  </div>
                </>
              )}

              <div>
                <label className="block text-sm font-medium text-slate-700 mb-1">Priority (lower = shown first)</label>
                <input
                  type="number"
                  min="0"
                  value={formData.priority ?? 0}
                  onChange={(e) => setFormData({ ...formData, priority: parseInt(e.target.value) })}
                  className="w-full px-3 py-2 border border-slate-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-brand-500"
                />
              </div>

              <label className="flex items-center gap-2 cursor-pointer">
                <input
                  type="checkbox"
                  checked={!!formData.is_enabled}
                  onChange={(e) => setFormData({ ...formData, is_enabled: e.target.checked })}
                  className="rounded border-slate-200"
                />
                <span className="text-sm font-medium text-slate-700">
                  {isCash ? 'Allow cash payments' : 'Enabled'}
                </span>
              </label>

              <div className="flex gap-2 justify-end pt-4 border-t border-slate-200">
                <Button variant="outline" onClick={() => setEditingId(null)}>
                  Cancel
                </Button>
                <Button loading={updateMutation.isPending} onClick={handleSave}>
                  Save Changes
                </Button>
              </div>
            </div>
          </Modal>
        );
      })()}
    </PageWrapper>
  );
}
