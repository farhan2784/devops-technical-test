const { createServer } = require('http');
const port = process.env.PORT || 80;

createServer((req, res) => {
  if (req.url === '/hello' && req.method === 'GET') {
    res.writeHead(200, { 'Content-Type': 'text/plain' });
    return res.end('OK');
  }
  res.writeHead(404);
  res.end('Not Found');
}).listen(port);

console.log(`Server running on port ${port}`);

