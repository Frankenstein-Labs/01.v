import { isStage, withNodeIds, buildFlowEdges, measureNode, connectorPath } from 'ee/cd/flow_graph';

const step = (title) => ({ kind: 'step', title });

const stage = (...titles) => ({
  kind: 'stage',
  title: 'stage',
  steps: titles.map((title) => ({ title })),
});

const edgeList = (items, expanded) =>
  buildFlowEdges(items, expanded).map(({ from, to }) => `${from} -> ${to}`);

describe('isStage', () => {
  it.each([
    ['a stage item', { kind: 'stage' }, true],
    ['a step item', { kind: 'step' }, false],
  ])('returns %p for %s', (_scenario, item, expected) => {
    expect(isStage(item)).toBe(expected);
  });
});

describe('withNodeIds', () => {
  it('stamps a node id on every item', () => {
    const items = withNodeIds([step('Trigger'), stage('Deploy')]);

    expect(items.map(({ nodeId }) => nodeId)).toEqual(['item-0', 'item-1']);
  });

  it("stamps a node id on every one of a stage's steps", () => {
    const [, item] = withNodeIds([step('Trigger'), stage('a', 'b')]);

    expect(item.steps.map(({ nodeId }) => nodeId)).toEqual(['item-1-step-0', 'item-1-step-1']);
  });

  it('leaves the items it was given untouched', () => {
    const items = [step('Trigger'), stage('a')];
    withNodeIds(items);

    expect(items[0].nodeId).toBeUndefined();
    expect(items[1].steps[0].nodeId).toBeUndefined();
  });
});

describe('buildFlowEdges', () => {
  it('chains a sequence of bare steps', () => {
    const items = withNodeIds([step('a'), step('b'), step('c')]);

    expect(edgeList(items, [])).toEqual(['item-0 -> item-1', 'item-1 -> item-2']);
  });

  it('targets the stage itself while it is collapsed', () => {
    const items = withNodeIds([step('a'), stage('x', 'y'), step('b')]);

    expect(edgeList(items, [false, false, false])).toEqual([
      'item-0 -> item-1',
      'item-1 -> item-2',
    ]);
  });

  it('runs through the inner steps once the stage is expanded', () => {
    const items = withNodeIds([step('a'), stage('x', 'y'), step('b')]);

    expect(edgeList(items, [false, true, false])).toEqual([
      'item-0 -> item-1-step-0',
      'item-1-step-0 -> item-1-step-1',
      'item-1-step-1 -> item-2',
    ]);
  });

  it('emits no edges for a single item', () => {
    expect(edgeList(withNodeIds([step('only')]), [])).toEqual([]);
  });

  it('keeps the chain intact for an expanded stage with no steps', () => {
    const items = withNodeIds([step('a'), stage(), step('b')]);

    expect(edgeList(items, [false, true, false])).toEqual(['item-0 -> item-1', 'item-1 -> item-2']);
  });
});

describe('measureNode', () => {
  it('returns edges and vertical centre relative to the container', () => {
    const element = {
      getBoundingClientRect: () => ({ left: 130, right: 186, top: 240, height: 56 }),
    };

    expect(measureNode(element, { left: 100, top: 200 })).toEqual({
      left: 30,
      right: 86,
      centerY: 68,
    });
  });
});

describe('connectorPath', () => {
  it('draws a flat path when both nodes share a vertical centre', () => {
    const path = connectorPath({ right: 100, centerY: 50 }, { left: 200, centerY: 50 });

    expect(path).toBe('M100,50C150,50,150,50,200,50');
  });

  it('curves from the source right edge to the target left edge at different heights', () => {
    const path = connectorPath({ right: 100, centerY: 150 }, { left: 200, centerY: 50 });

    expect(path).toBe('M100,150C150,150,150,50,200,50');
  });
});
