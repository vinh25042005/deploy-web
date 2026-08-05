const client = require('prom-client');

// Metrics mặc định của nodejs (event loop, heap, v.v.) — prefix app_
client.collectDefaultMetrics({ prefix: 'app_' });

/**
 * app_info{version, commit, built_at} — giá trị = epoch build time.
 *
 * Được dùng cho dashboard DORA:
 *   - Deploy frequency: sum by (namespace) (changes(app_info[7d]))
 *   - Lead time (đến hiện tại): time() - app_info
 * Nếu cần đo commit→prod chính xác hơn, so sánh built_at này với
 * thời điểm commit được tạo trên GitHub.
 */
const appInfo = new client.Gauge({
  name: 'app_info',
  help: 'Version, commit and build timestamp of the deployed service',
  labelNames: ['version', 'commit', 'built_at'],
  aggregator: 'first',
});

function setAppInfo({ version, commit, builtAt }) {
  appInfo.set({ version, commit, built_at: String(builtAt) }, builtAt);
}

module.exports = { register: client.register, setAppInfo };
