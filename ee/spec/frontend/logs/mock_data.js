export const mockLogs = [
  {
    fingerprint: 'log-1',
    timestamp: '2024-01-28T10:36:08.2960655Z',
    trace_id: 'trace-id',
    span_id: 'span-id',
    trace_flags: 1,
    severity_text: 'Information',
    severity_number: 1,
    service_name: 'a/service/name',
    body: 'GetCartAsync called with userId={userId}',
    resource_attributes: {
      'container.id': '8aae63236c224245383acd38611a4e32d09b7630573421fcc801918eda378bf5',
      'k8s.deployment.name': 'otel-demo-cartservice',
    },
    log_attributes: {
      userId: 'user-id',
    },
  },
  {
    fingerprint: 'log-2',
    timestamp: '2024-01-28T10:36:08.2960655Z',
    trace_id: 'trace-id',
    span_id: 'span-id',
    trace_flags: 1,
    severity_text: 'Information',
    severity_number: 9,
    service_name: 'cartservice',
    body: 'GetCartAsync called with userId={userId}',
    resource_attributes: {
      'container.id': '8aae63236c224245383acd38611a4e32d09b7630573421fcc801918eda378bf5',
      'k8s.deployment.name': 'otel-demo-cartservice',
      'k8s.namespace.name': 'otel-demo-app',
      'k8s.node.name': 'opstrace-worker',
      'k8s.pod.ip': '192.168.95.20',
      'k8s.pod.name': 'otel-demo-cartservice-6dcc867f5f-gfhcx',
      'k8s.pod.start_time': '2024-01-26T09:36:26Z',
      'k8s.pod.uid': 'b1f88956-bdbd-4dba-8067-ac9be923dc83',
      'service.name': 'cartservice',
      'service.namespace': 'opentelemetry-demo',
      'telemetry.sdk.language': 'dotnet',
      'telemetry.sdk.name': 'opentelemetry',
      'telemetry.sdk.version': '1.6.0',
    },
    log_attributes: {
      userId: '',
    },
  },
  {
    fingerprint: 'log-3',
    timestamp: '2024-01-28T10:36:08.2960655Z',
    trace_id: 'trace-id',
    span_id: 'span-id',
    trace_flags: 1,
    severity_text: 'Information',
    severity_number: 13,
    service_name: 'cartservice',
    body: 'GetCartAsync called with userId={userId}',
    resource_attributes: {
      'container.id': '8aae63236c224245383acd38611a4e32d09b7630573421fcc801918eda378bf5',
      'k8s.deployment.name': 'otel-demo-cartservice',
      'k8s.namespace.name': 'otel-demo-app',
      'k8s.node.name': 'opstrace-worker',
      'k8s.pod.ip': '192.168.95.20',
      'k8s.pod.name': 'otel-demo-cartservice-6dcc867f5f-gfhcx',
      'k8s.pod.start_time': '2024-01-26T09:36:26Z',
      'k8s.pod.uid': 'b1f88956-bdbd-4dba-8067-ac9be923dc83',
      'service.name': 'cartservice',
      'service.namespace': 'opentelemetry-demo',
      'telemetry.sdk.language': 'dotnet',
      'telemetry.sdk.name': 'opentelemetry',
      'telemetry.sdk.version': '1.6.0',
    },
    log_attributes: {
      userId: '',
    },
  },
  {
    fingerprint: 'log-4',
    timestamp: '2024-01-28T10:36:08.2960655Z',
    trace_id: 'trace-id',
    span_id: 'span-id',
    trace_flags: 1,
    severity_text: 'Information',
    severity_number: 17,
    service_name: 'cartservice',
    body: 'GetCartAsync called with userId={userId}',
    resource_attributes: {
      'container.id': '8aae63236c224245383acd38611a4e32d09b7630573421fcc801918eda378bf5',
      'k8s.deployment.name': 'otel-demo-cartservice',
      'k8s.namespace.name': 'otel-demo-app',
      'k8s.node.name': 'opstrace-worker',
      'k8s.pod.ip': '192.168.95.20',
      'k8s.pod.name': 'otel-demo-cartservice-6dcc867f5f-gfhcx',
      'k8s.pod.start_time': '2024-01-26T09:36:26Z',
      'k8s.pod.uid': 'b1f88956-bdbd-4dba-8067-ac9be923dc83',
      'service.name': 'cartservice',
      'service.namespace': 'opentelemetry-demo',
      'telemetry.sdk.language': 'dotnet',
      'telemetry.sdk.name': 'opentelemetry',
      'telemetry.sdk.version': '1.6.0',
    },
    log_attributes: {
      userId: '',
    },
  },
  {
    fingerprint: 'log-5',
    timestamp: '2024-01-28T10:36:08.2960655Z',
    trace_id: 'trace-id',
    span_id: 'span-id',
    trace_flags: 1,
    severity_text: 'Information',
    severity_number: 21,
    service_name: 'cartservice',
    body: 'GetCartAsync called with userId={userId}',
    resource_attributes: {
      'container.id': '8aae63236c224245383acd38611a4e32d09b7630573421fcc801918eda378bf5',
      'k8s.deployment.name': 'otel-demo-cartservice',
      'k8s.namespace.name': 'otel-demo-app',
      'k8s.node.name': 'opstrace-worker',
      'k8s.pod.ip': '192.168.95.20',
      'k8s.pod.name': 'otel-demo-cartservice-6dcc867f5f-gfhcx',
      'k8s.pod.start_time': '2024-01-26T09:36:26Z',
      'k8s.pod.uid': 'b1f88956-bdbd-4dba-8067-ac9be923dc83',
      'service.name': 'cartservice',
      'service.namespace': 'opentelemetry-demo',
      'telemetry.sdk.language': 'dotnet',
      'telemetry.sdk.name': 'opentelemetry',
      'telemetry.sdk.version': '1.6.0',
    },
    log_attributes: {
      userId: '',
    },
  },
];

export const mockMetadata = {
  start_ts: 1713513680617331200,
  end_ts: 1714723280617331200,
  summary: {
    service_names: ['adservice', 'cartservice', 'quoteservice', 'recommendationservice'],
    trace_flags: [0, 1],
    severity_names: ['info', 'warn'],
    severity_numbers: [9, 13],
  },
  severity_numbers_counts: [
    {
      time: 1713519360000000000,
      counts: {
        13: 0,
        9: 0,
      },
    },
    {
      time: 1713545280000000000,
      counts: {
        13: 0,
        9: 0,
      },
    },
    {
      time: 1713571200000000000,
      counts: {
        13: 0,
        9: 0,
      },
    },
    {
      time: 1713597120000000000,
      counts: {
        13: 0,
        9: 0,
      },
    },
    {
      time: 1713623040000000000,
      counts: {
        13: 0,
        9: 0,
      },
    },
    {
      time: 1713648960000000000,
      counts: {
        13: 0,
        9: 0,
      },
    },
    {
      time: 1713674880000000000,
      counts: {
        13: 0,
        9: 0,
      },
    },
    {
      time: 1713700800000000000,
      counts: {
        13: 0,
        9: 0,
      },
    },
    {
      time: 1713726720000000000,
      counts: {
        13: 0,
        9: 0,
      },
    },
    {
      time: 1713752640000000000,
      counts: {
        13: 0,
        9: 0,
      },
    },
    {
      time: 1713778560000000000,
      counts: {
        13: 0,
        9: 0,
      },
    },
    {
      time: 1713804480000000000,
      counts: {
        13: 0,
        9: 0,
      },
    },
    {
      time: 1713830400000000000,
      counts: {
        13: 0,
        9: 0,
      },
    },
    {
      time: 1713856320000000000,
      counts: {
        13: 0,
        9: 0,
      },
    },
    {
      time: 1713882240000000000,
      counts: {
        13: 0,
        9: 0,
      },
    },
    {
      time: 1713908160000000000,
      counts: {
        13: 0,
        9: 0,
      },
    },
    {
      time: 1713934080000000000,
      counts: {
        13: 0,
        9: 0,
      },
    },
    {
      time: 1713960000000000000,
      counts: {
        13: 0,
        9: 0,
      },
    },
    {
      time: 1713985920000000000,
      counts: {
        13: 0,
        9: 0,
      },
    },
    {
      time: 1714011840000000000,
      counts: {
        13: 0,
        9: 0,
      },
    },
    {
      time: 1714037760000000000,
      counts: {
        13: 0,
        9: 0,
      },
    },
    {
      time: 1714063680000000000,
      counts: {
        13: 0,
        9: 0,
      },
    },
    {
      time: 1714089600000000000,
      counts: {
        13: 0,
        9: 0,
      },
    },
    {
      time: 1714115520000000000,
      counts: {
        13: 0,
        9: 0,
      },
    },
    {
      time: 1714141440000000000,
      counts: {
        13: 0,
        9: 0,
      },
    },
    {
      time: 1714167360000000000,
      counts: {
        13: 0,
        9: 0,
      },
    },
    {
      time: 1714193280000000000,
      counts: {
        13: 0,
        9: 0,
      },
    },
    {
      time: 1714219200000000000,
      counts: {
        13: 0,
        9: 0,
      },
    },
    {
      time: 1714245120000000000,
      counts: {
        13: 0,
        9: 0,
      },
    },
    {
      time: 1714271040000000000,
      counts: {
        13: 0,
        9: 0,
      },
    },
    {
      time: 1714296960000000000,
      counts: {
        13: 0,
        9: 0,
      },
    },
    {
      time: 1714322880000000000,
      counts: {
        13: 1,
        9: 26202,
      },
    },
    {
      time: 1714348800000000000,
      counts: {
        13: 0,
        9: 53103,
      },
    },
    {
      time: 1714374720000000000,
      counts: {
        13: 0,
        9: 52854,
      },
    },
    {
      time: 1714400640000000000,
      counts: {
        13: 0,
        9: 49598,
      },
    },
    {
      time: 1714426560000000000,
      counts: {
        13: 0,
        9: 45266,
      },
    },
    {
      time: 1714452480000000000,
      counts: {
        13: 0,
        9: 44951,
      },
    },
    {
      time: 1714478400000000000,
      counts: {
        13: 0,
        9: 45096,
      },
    },
    {
      time: 1714504320000000000,
      counts: {
        13: 0,
        9: 45301,
      },
    },
    {
      time: 1714530240000000000,
      counts: {
        13: 0,
        9: 44894,
      },
    },
    {
      time: 1714556160000000000,
      counts: {
        13: 0,
        9: 45444,
      },
    },
    {
      time: 1714582080000000000,
      counts: {
        13: 0,
        9: 45067,
      },
    },
    {
      time: 1714608000000000000,
      counts: {
        13: 0,
        9: 45119,
      },
    },
    {
      time: 1714633920000000000,
      counts: {
        13: 0,
        9: 45817,
      },
    },
    {
      time: 1714659840000000000,
      counts: {
        13: 0,
        9: 44574,
      },
    },
    {
      time: 1714685760000000000,
      counts: {
        13: 0,
        9: 44652,
      },
    },
    {
      time: 1714711680000000000,
      counts: {
        13: 0,
        9: 20470,
      },
    },
  ],
};
