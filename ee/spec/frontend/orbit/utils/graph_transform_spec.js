import {
  transformGraphResponse,
  mergeNeighborNodes,
  aggregationRowsToTable,
} from 'ee/orbit/utils/graph_transform';

describe('transformGraphResponse', () => {
  it('creates nodes with composite ids', () => {
    const response = {
      nodes: [
        { type: 'User', id: 1, username: 'admin' },
        { type: 'User', id: 2, username: 'dev' },
      ],
      edges: [],
    };

    const { nodes } = transformGraphResponse(response);

    expect(nodes).toHaveLength(2);
    expect(nodes[0].id).toBe('User_1');
    expect(nodes[1].id).toBe('User_2');
  });

  it('creates edges between nodes', () => {
    const response = {
      nodes: [
        { type: 'User', id: 1, username: 'admin' },
        { type: 'Project', id: 10, name: 'GitLab' },
      ],
      edges: [{ from: 'User', from_id: 1, to: 'Project', to_id: 10, type: 'OWNS' }],
    };

    const { nodes, edges } = transformGraphResponse(response);

    expect(nodes).toHaveLength(2);
    expect(edges).toHaveLength(1);
    expect(edges[0].source).toBe(0);
    expect(edges[0].target).toBe(1);
  });

  it('uses name as label when available', () => {
    const response = {
      nodes: [{ type: 'User', id: 1, name: 'Admin' }],
      edges: [],
    };

    const { nodes } = transformGraphResponse(response);

    expect(nodes[0].label).toBe('Admin');
  });

  it('falls back to username, full_path, then id for label', () => {
    const byUsername = transformGraphResponse({
      nodes: [{ type: 'User', id: 1, username: 'dev' }],
      edges: [],
    });

    expect(byUsername.nodes[0].label).toBe('dev');

    const byPath = transformGraphResponse({
      nodes: [{ type: 'Group', id: 2, full_path: 'org/team' }],
      edges: [],
    });

    expect(byPath.nodes[0].label).toBe('org/team');

    const byId = transformGraphResponse({
      nodes: [{ type: 'Unknown', id: 99 }],
      edges: [],
    });

    expect(byId.nodes[0].label).toBe('');
  });

  it('uses labelField from nodeStyleMap when provided', () => {
    const response = {
      nodes: [{ type: 'User', id: 1, email: 'a@b.com', username: 'dev' }],
      edges: [],
    };

    const { nodes } = transformGraphResponse(response, { user: { labelField: 'email' } });

    expect(nodes[0].label).toBe('a@b.com');
  });

  it('skips edges referencing unknown nodes', () => {
    const response = {
      nodes: [{ type: 'User', id: 1 }],
      edges: [{ from: 'User', from_id: 1, to: 'Ghost', to_id: 999, type: 'LINK' }],
    };

    const { edges } = transformGraphResponse(response);

    expect(edges).toHaveLength(0);
  });
});

describe('mergeNeighborNodes', () => {
  const existingNodes = [
    { id: 'User_1', label: 'Admin', type: 'user', domain: null, properties: { id: 1 } },
  ];

  it('adds new nodes not already in the graph', () => {
    const response = {
      nodes: [{ type: 'Project', id: 10, name: 'GitLab' }],
      edges: [],
    };

    const { newNodes } = mergeNeighborNodes(response, existingNodes);

    expect(newNodes).toHaveLength(1);
    expect(newNodes[0].id).toBe('Project_10');
    expect(newNodes[0].label).toBe('GitLab');
  });

  it('skips nodes already in the graph', () => {
    const response = {
      nodes: [{ type: 'User', id: 1, username: 'admin' }],
      edges: [],
    };

    const { newNodes } = mergeNeighborNodes(response, existingNodes);

    expect(newNodes).toHaveLength(0);
  });

  it('creates edges between existing and new nodes', () => {
    const response = {
      nodes: [
        { type: 'User', id: 1 },
        { type: 'Project', id: 10, name: 'GitLab' },
      ],
      edges: [{ from: 'User', from_id: 1, to: 'Project', to_id: 10, type: 'OWNS' }],
    };

    const { newEdges } = mergeNeighborNodes(response, existingNodes);

    expect(newEdges).toHaveLength(1);
    expect(newEdges[0].source).toBe(0);
    expect(newEdges[0].target).toBe(1);
    expect(newEdges[0].type).toBe('OWNS');
  });

  it('handles nodes without a type', () => {
    const response = {
      nodes: [{ id: 5 }],
      edges: [],
    };

    const { newNodes } = mergeNeighborNodes(response, existingNodes);

    expect(newNodes).toHaveLength(0);
  });

  it('skips self-referencing edges', () => {
    const response = {
      nodes: [{ type: 'User', id: 1 }],
      edges: [{ from: 'User', from_id: 1, to: 'User', to_id: 1, type: 'SELF' }],
    };

    const { newEdges } = mergeNeighborNodes(response, existingNodes);

    expect(newEdges).toHaveLength(0);
  });
});

describe('aggregationRowsToTable', () => {
  it('expands node-cell group keys into their properties alongside metrics', () => {
    const rows = [
      { u: { type: 'User', id: '101', properties: { username: 'alice' } }, mr_count: 5 },
      { u: { type: 'User', id: '102', properties: { username: 'bob' } }, mr_count: 3 },
    ];

    expect(aggregationRowsToTable(rows)).toEqual([
      { username: 'alice', mr_count: 5 },
      { username: 'bob', mr_count: 3 },
    ]);
  });

  it('passes scalar group keys and metrics through unchanged', () => {
    const rows = [{ severity: 'high', vuln_count: 12 }];

    expect(aggregationRowsToTable(rows)).toEqual([{ severity: 'high', vuln_count: 12 }]);
  });

  it('falls back to the node id when a node cell has no properties', () => {
    const rows = [{ p: { type: 'Project', id: '7', properties: {} }, count: 1 }];

    expect(aggregationRowsToTable(rows)).toEqual([{ p: '7', count: 1 }]);
  });

  it('returns an empty array when given no rows', () => {
    expect(aggregationRowsToTable()).toEqual([]);
  });
});
