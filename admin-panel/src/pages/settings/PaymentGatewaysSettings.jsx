import { useState, useEffect } from 'react';
import {
  Table, TableBody, TableCell, TableContainer, TableHead, TableRow, Paper,
  Button, Dialog, DialogTitle, DialogContent, DialogActions, TextField,
  Switch, FormControlLabel, Box, Card, CardContent, Typography, Chip,
  CircularProgress, Alert, Container, Grid,
} from '@mui/material';
import { Edit as EditIcon, ToggleOff as DisableIcon, ToggleOn as EnableIcon } from '@mui/icons-material';
import { paymentGatewaysApi } from '../../api/payments';

export default function PaymentGatewaysSettings() {
  const [gateways, setGateways] = useState([]);
  const [stats, setStats] = useState(null);
  const [loading, setLoading] = useState(true);
  const [editDialog, setEditDialog] = useState(false);
  const [selectedGateway, setSelectedGateway] = useState(null);
  const [formData, setFormData] = useState({});
  const [error, setError] = useState(null);
  const [success, setSuccess] = useState(null);

  useEffect(() => {
    fetchGateways();
    fetchStats();
  }, []);

  const fetchGateways = async () => {
    try {
      setLoading(true);
      const response = await paymentGatewaysApi.list();
      setGateways(response.data);
      setError(null);
    } catch (err) {
      setError(err.response?.data?.message || 'Failed to load payment gateways');
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  const fetchStats = async () => {
    try {
      const response = await paymentGatewaysApi.stats();
      setStats(response.data);
    } catch (err) {
      console.error('Failed to fetch stats:', err);
    }
  };

  const handleEditClick = (gateway) => {
    setSelectedGateway(gateway);
    setFormData(gateway);
    setEditDialog(true);
  };

  const handleToggle = async (gatewayId) => {
    try {
      await paymentGatewaysApi.toggle(gatewayId);
      setSuccess('Gateway status updated');
      fetchGateways();
      setTimeout(() => setSuccess(null), 3000);
    } catch (err) {
      setError(err.response?.data?.message || 'Failed to update gateway');
    }
  };

  const handleSaveChanges = async () => {
    try {
      await paymentGatewaysApi.update(selectedGateway.id, formData);
      setSuccess('Gateway updated successfully');
      setEditDialog(false);
      fetchGateways();
      setTimeout(() => setSuccess(null), 3000);
    } catch (err) {
      setError(err.response?.data?.message || 'Failed to update gateway');
    }
  };

  const handleFormChange = (field, value) => {
    setFormData({
      ...formData,
      [field]: value,
    });
  };

  if (loading) {
    return (
      <Container maxWidth="lg" sx={{ py: 4, display: 'flex', justifyContent: 'center' }}>
        <CircularProgress />
      </Container>
    );
  }

  return (
    <Container maxWidth="lg" sx={{ py: 4 }}>
      <Box sx={{ mb: 4 }}>
        <Typography variant="h4" gutterBottom>
          Payment Gateway Settings
        </Typography>
        <Typography variant="body2" color="textSecondary">
          Manage payment gateways, configure credentials, set transaction limits and fees
        </Typography>
      </Box>

      {error && (
        <Alert severity="error" sx={{ mb: 3 }} onClose={() => setError(null)}>
          {error}
        </Alert>
      )}
      {success && (
        <Alert severity="success" sx={{ mb: 3 }} onClose={() => setSuccess(null)}>
          {success}
        </Alert>
      )}

      {/* Statistics Cards */}
      {stats && (
        <Grid container spacing={2} sx={{ mb: 4 }}>
          {stats.map((stat) => (
            <Grid item xs={12} sm={6} md={3} key={stat.name}>
              <Card>
                <CardContent>
                  <Typography color="textSecondary" gutterBottom>
                    {stat.display_name}
                  </Typography>
                  <Typography variant="h6">
                    {stat.total_transactions} transactions
                  </Typography>
                  <Typography variant="body2" color="textSecondary">
                    ₦{parseFloat(stat.total_amount || 0).toLocaleString('en-NG')}
                  </Typography>
                  <Box sx={{ mt: 1, display: 'flex', gap: 1 }}>
                    <Chip label={`✓ ${stat.successful_count}`} size="small" color="success" variant="outlined" />
                    <Chip label={`✗ ${stat.failed_count}`} size="small" color="error" variant="outlined" />
                  </Box>
                </CardContent>
              </Card>
            </Grid>
          ))}
        </Grid>
      )}

      {/* Gateways Table */}
      <TableContainer component={Paper}>
        <Table>
          <TableHead sx={{ backgroundColor: '#f5f5f5' }}>
            <TableRow>
              <TableCell><strong>Gateway</strong></TableCell>
              <TableCell align="center"><strong>Status</strong></TableCell>
              <TableCell align="right"><strong>Min Amount</strong></TableCell>
              <TableCell align="right"><strong>Max Amount</strong></TableCell>
              <TableCell align="right"><strong>Fee (%)</strong></TableCell>
              <TableCell align="right"><strong>Fixed Fee</strong></TableCell>
              <TableCell align="center"><strong>Actions</strong></TableCell>
            </TableRow>
          </TableHead>
          <TableBody>
            {gateways.map((gateway) => (
              <TableRow key={gateway.id} hover>
                <TableCell>
                  <Typography variant="body2" fontWeight={600}>
                    {gateway.display_name}
                  </Typography>
                  <Typography variant="caption" color="textSecondary">
                    ({gateway.name})
                  </Typography>
                </TableCell>
                <TableCell align="center">
                  {gateway.is_enabled ? (
                    <Chip label="Enabled" color="success" size="small" />
                  ) : (
                    <Chip label="Disabled" color="error" size="small" />
                  )}
                </TableCell>
                <TableCell align="right">
                  ₦{parseFloat(gateway.min_amount).toLocaleString('en-NG')}
                </TableCell>
                <TableCell align="right">
                  ₦{parseFloat(gateway.max_amount).toLocaleString('en-NG')}
                </TableCell>
                <TableCell align="right">{gateway.transaction_fee_percent.toFixed(2)}%</TableCell>
                <TableCell align="right">
                  ₦{parseFloat(gateway.transaction_fee_fixed).toLocaleString('en-NG')}
                </TableCell>
                <TableCell align="center" sx={{ display: 'flex', gap: 1, justifyContent: 'center' }}>
                  <Button
                    size="small"
                    variant="outlined"
                    startIcon={<EditIcon />}
                    onClick={() => handleEditClick(gateway)}
                  >
                    Edit
                  </Button>
                  <Button
                    size="small"
                    variant={gateway.is_enabled ? 'contained' : 'outlined'}
                    color={gateway.is_enabled ? 'success' : 'error'}
                    startIcon={gateway.is_enabled ? <EnableIcon /> : <DisableIcon />}
                    onClick={() => handleToggle(gateway.id)}
                  >
                    {gateway.is_enabled ? 'Enabled' : 'Disabled'}
                  </Button>
                </TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      </TableContainer>

      {/* Edit Dialog */}
      <Dialog open={editDialog} onClose={() => setEditDialog(false)} maxWidth="sm" fullWidth>
        <DialogTitle>Edit {selectedGateway?.display_name}</DialogTitle>
        <DialogContent sx={{ pt: 3, display: 'flex', flexDirection: 'column', gap: 2 }}>
          <TextField
            label="Display Name"
            value={formData.display_name || ''}
            onChange={(e) => handleFormChange('display_name', e.target.value)}
            fullWidth
          />

          <TextField
            label="Public Key"
            value={formData.public_key || ''}
            onChange={(e) => handleFormChange('public_key', e.target.value)}
            fullWidth
            type="password"
          />

          <TextField
            label="Secret Key"
            value={formData.secret_key || ''}
            onChange={(e) => handleFormChange('secret_key', e.target.value)}
            fullWidth
            type="password"
          />

          <TextField
            label="Webhook Secret"
            value={formData.webhook_secret || ''}
            onChange={(e) => handleFormChange('webhook_secret', e.target.value)}
            fullWidth
            type="password"
          />

          <TextField
            label="Minimum Amount (₦)"
            type="number"
            inputProps={{ step: '0.01' }}
            value={formData.min_amount || 0}
            onChange={(e) => handleFormChange('min_amount', parseFloat(e.target.value))}
            fullWidth
          />

          <TextField
            label="Maximum Amount (₦)"
            type="number"
            inputProps={{ step: '0.01' }}
            value={formData.max_amount || 999999.99}
            onChange={(e) => handleFormChange('max_amount', parseFloat(e.target.value))}
            fullWidth
          />

          <TextField
            label="Transaction Fee (%)"
            type="number"
            inputProps={{ step: '0.01', min: '0' }}
            value={formData.transaction_fee_percent || 0}
            onChange={(e) => handleFormChange('transaction_fee_percent', parseFloat(e.target.value))}
            fullWidth
          />

          <TextField
            label="Fixed Fee (₦)"
            type="number"
            inputProps={{ step: '0.01', min: '0' }}
            value={formData.transaction_fee_fixed || 0}
            onChange={(e) => handleFormChange('transaction_fee_fixed', parseFloat(e.target.value))}
            fullWidth
          />

          <TextField
            label="Priority (Display Order)"
            type="number"
            inputProps={{ min: '0' }}
            value={formData.priority || 0}
            onChange={(e) => handleFormChange('priority', parseInt(e.target.value))}
            fullWidth
          />

          <FormControlLabel
            control={
              <Switch
                checked={formData.is_enabled || false}
                onChange={(e) => handleFormChange('is_enabled', e.target.checked)}
              />
            }
            label="Enabled"
          />
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setEditDialog(false)}>Cancel</Button>
          <Button onClick={handleSaveChanges} variant="contained" color="primary">
            Save Changes
          </Button>
        </DialogActions>
      </Dialog>
    </Container>
  );
}
