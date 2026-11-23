// Test de charge k6 - charge nominale et verification des SLO (section 3.3)
import http from "k6/http";
import { check, sleep } from "k6";

const CIBLE = __ENV.CIBLE;

export const options = {
  scenarios: {
    nominal: {
      executor: "ramping-vus",
      startVUs: 0,
      stages: [
        { duration: "30s", target: 20 },
        { duration: "2m", target: 20 },
        { duration: "30s", target: 0 },
      ],
    },
  },
  thresholds: {
    http_req_failed: ["rate<0.005"],          // taux d'erreur < 0,5 %
    "http_req_duration{type:api}": ["p(95)<500", "p(99)<1000"],
    "http_req_duration{type:page}": ["p(95)<500", "p(99)<1000"],
  },
  summaryTrendStats: ["avg", "min", "med", "p(90)", "p(95)", "p(99)", "max"],
};

export default function () {
  const page = http.get(`${CIBLE}/`, { tags: { type: "page" } });
  check(page, { "accueil 200": (r) => r.status === 200 });
  const css = http.get(`${CIBLE}/static/style.css`, { tags: { type: "statique" } });
  check(css, { "statique 200": (r) => r.status === 200 });
  const api = http.get(`${CIBLE}/api/portefeuilles`, { tags: { type: "api" } });
  check(api, { "api 200": (r) => r.status === 200 });
  sleep(1);
}

export function handleSummary(donnees) {
  return { "docs/rapports/k6-resume.json": JSON.stringify(donnees, null, 2) };
}
