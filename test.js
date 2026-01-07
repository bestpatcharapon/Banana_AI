import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  stages: [
    { duration: '10s', target: 10 },  // Ramp up to 10 VUs
    { duration: '20s', target: 100 },  // Ramp up to 100 VUs (เพิ่มจาก 20)
    { duration: '10s', target: 0 },   // Ramp down to 0
  ],
  thresholds: {
    http_req_duration: ['p(95)<500'],  // เข้มงวด - จะ FAIL
    http_req_failed: ['rate<0.01'],    // เข้มงวด - error < 1%
  },
};

export default function () {
  const res = http.get('https://bananacoding.com/');

  check(res, {
    'status is 200': (r) => r.status === 200,
    'response time < 500ms': (r) => r.timings.duration < 500,
  });

  sleep(1);
}