// Quick OSC sender for smoke-testing the receiver. Run with `node test-osc.js`.
const osc = require('osc');

const port = new osc.UDPPort({
  localAddress: '0.0.0.0',
  localPort: 0,
  remoteAddress: '127.0.0.1',
  remotePort: 9000,
  metadata: false,
});

const messages = [
  { address: '/704/shader',      args: [0] },          // Aurora
  { address: '/704/shader/next', args: [1.0] },        // → next
  { address: '/704/shader/next', args: [] },           // → next again (no arg = trigger)
  { address: '/704/shader/prev', args: [1.0] },        // → back
];

port.on('ready', () => {
  console.log('[test] sending', messages.length, 'OSC messages to 127.0.0.1:9000');
  let i = 0;
  const tick = () => {
    if (i >= messages.length) {
      console.log('[test] done');
      port.close();
      process.exit(0);
    }
    const m = messages[i++];
    port.send(m);
    console.log('[test] →', m.address, JSON.stringify(m.args));
    setTimeout(tick, 400);
  };
  tick();
});

port.on('error', (e) => {
  console.error('[test] error:', e);
  process.exit(1);
});

port.open();
