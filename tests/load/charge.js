// Test de charge k6 - charge nominale (10 utilisateurs virtuels, ~25 req/s) et verification des SLO (section 3.3)
import http from "k6/http";
import { check, sleep } from "k6";
import { textSummary } from "https://jslib.k6.io/k6-summary/0.0.2/index.js";

const CIBLE = __ENV.CIBLE;

export const options = {
  scenarios: {
    nominal: {
      executor: "ramping-vus",
      startVUs: 0,
      stages: [
        { duration: "30s", target: 10 },
        { duration: "2m", target: 10 },
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
  if (page.status !== 200) console.warn(`accueil ${page.status} ${page.headers["X-Cache"] || ""}`);
  const css = http.get(`${CIBLE}/static/style.css`, { tags: { type: "statique" } });
  check(css, { "statique 200": (r) => r.status === 200 });
  if (css.status !== 200) console.warn(`statique ${css.status} ${css.headers["X-Cache"] || ""}`);
  const api = http.get(`${CIBLE}/api/portefeuilles`, { tags: { type: "api" } });
  check(api, { "api 200": (r) => r.status === 200 });
  if (api.status !== 200) console.warn(`api ${api.status} ${api.headers["X-Cache"] || ""}`);
  sleep(1);
}

export function handleSummary(donnees) {
  return {
    stdout: textSummary(donnees, { indent: " ", enableColors: false }),
    "docs/rapports/k6-resume.json": JSON.stringify(donnees, null, 2),
  };
}
