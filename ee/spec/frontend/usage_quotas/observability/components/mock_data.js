export const mockEventsData = {
  start_ts: 1719792000000000000,
  end_ts: 1722384000000000000,
  aggregated_total: 29907569,
  aggregated_per_feature: { logs: 1167161, metrics: 1183855, traces: 27556553 },
  data: {
    logs: [
      [1720310400000000000, 575751],
      [1720396800000000000, 591410],
    ],
    metrics: [
      [1720310400000000000, 553617],
      [1720396800000000000, 630238],
    ],
    traces: [
      [1720310400000000000, 13786470],
      [1720396800000000000, 13770083],
    ],
  },
  data_breakdown: 'daily',
  data_unit: '',
};

export const mockStorageData = {
  start_ts: 1719792000000000000,
  end_ts: 1722384000000000000,
  aggregated_total: 36666726067,
  aggregated_per_feature: { logs: 986845920, metrics: 1251314399, traces: 34428565748 },
  data: {
    logs: [
      [1720310400000000000, 481626089],
      [1720396800000000000, 505219831],
    ],
    metrics: [
      [1720310400000000000, 588125804],
      [1720396800000000000, 663188595],
    ],
    traces: [
      [1720310400000000000, 17207830769],
      [1720396800000000000, 17220734979],
    ],
  },
  data_breakdown: 'daily',
  data_unit: 'bytes',
};

export const mockData = {
  events: {
    7: { ...mockEventsData },
  },
  storage: {
    7: { ...mockStorageData },
  },
};
