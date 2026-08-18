import { linkHorizontal, pairs } from 'd3';
import { FLOW_ITEM_STAGE } from './constants';

const link = linkHorizontal();

export const isStage = (item) => item.kind === FLOW_ITEM_STAGE;

const itemNodeId = (itemIndex) => `item-${itemIndex}`;

const stepNodeId = (itemIndex, stepIndex) => `item-${itemIndex}-step-${stepIndex}`;

export const withNodeIds = (items) =>
  items.map((item, itemIndex) => {
    const nodeId = itemNodeId(itemIndex);

    if (!isStage(item)) {
      return { ...item, nodeId };
    }

    return {
      ...item,
      nodeId,
      steps: item.steps.map((step, stepIndex) => ({
        ...step,
        nodeId: stepNodeId(itemIndex, stepIndex),
      })),
    };
  });

const expandedSteps = (item, isExpanded) => (isStage(item) && isExpanded ? item.steps : []);

export const buildFlowEdges = (items, expandedItems = []) => {
  const nodes = items.map((item, itemIndex) => {
    const steps = expandedSteps(item, Boolean(expandedItems[itemIndex]));

    return {
      entry: steps[0]?.nodeId ?? item.nodeId,
      exit: steps.at(-1)?.nodeId ?? item.nodeId,
      within: pairs(steps, (from, to) => ({ from: from.nodeId, to: to.nodeId })),
    };
  });

  return nodes.flatMap((node, index) => [
    ...(index === 0 ? [] : [{ from: nodes[index - 1].exit, to: node.entry }]),
    ...node.within,
  ]);
};

export const measureNode = (element, containerRect) => {
  const rect = element.getBoundingClientRect();

  return {
    left: rect.left - containerRect.left,
    right: rect.right - containerRect.left,
    centerY: rect.top + rect.height / 2 - containerRect.top,
  };
};

export const connectorPath = (source, target) =>
  link({
    source: [source.right, source.centerY],
    target: [target.left, target.centerY],
  });
