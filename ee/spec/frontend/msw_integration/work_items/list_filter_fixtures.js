// Maps list filter variables to a generated fixture. Matchers must be exact: an
// unrecognised filter fails via `matchFixture` rather than borrowing another fixture.
// `fixtures` is a parameter, not an import, because `handlers.js` imports this module.
import { matchFixture } from '../fixture_utils';

const LABEL_TO_DO = 'To Do';
const LABEL_DOING = 'Doing';

const toLabelList = (value) => {
  if (Array.isArray(value)) return value;

  return value ? [value] : [];
};

const sameLabels = (value, expected) => {
  const actual = toLabelList(value);

  return actual.length === expected.length && expected.every((label) => actual.includes(label));
};

const labelFilterTable = (fixtures) => [
  {
    matches: ({ or }) => sameLabels(or?.labelNames, [LABEL_TO_DO, LABEL_DOING]),
    slim: () => fixtures.getWorkItemsSlimWithAnyOfLabels,
    full: () => fixtures.getWorkItemsFullWithAnyOfLabels,
  },
  {
    matches: ({ not }) => sameLabels(not?.labelName, [LABEL_TO_DO]),
    slim: () => fixtures.getWorkItemsSlimWithoutSpecificLabel,
    full: () => fixtures.getWorkItemsFullWithoutSpecificLabel,
  },
  {
    matches: ({ labelName }) => sameLabels(labelName, ['None']),
    slim: () => fixtures.getWorkItemsSlimWithNoLabel,
    full: () => fixtures.getWorkItemsFullWithNoLabel,
  },
  {
    matches: ({ labelName }) => sameLabels(labelName, ['Any']),
    slim: () => fixtures.getWorkItemsSlimWithAnyLabel,
    full: () => fixtures.getWorkItemsFullWithAnyLabel,
  },
  {
    matches: ({ labelName }) => sameLabels(labelName, [LABEL_TO_DO]),
    slim: () => fixtures.getWorkItemsSlimWithLabel,
    full: () => fixtures.getWorkItemsFullWithLabel,
  },
];

// Every shape a label filter can arrive in. `not.labelNames` is unreachable
// today — labels only use `labelNames` for the `||` operator — but is listed so
// it fails loudly rather than silently if that changes.
const readsLabelFilter = [
  ({ labelName }) => labelName,
  ({ not }) => not?.labelName,
  ({ not }) => not?.labelNames,
  ({ or }) => or?.labelNames,
];

const hasLabelFilter = (variables) =>
  readsLabelFilter.some((read) => toLabelList(read(variables)).length > 0);

export function buildListFilterMatcher(fixtures) {
  const table = labelFilterTable(fixtures);

  return (variables) => matchFixture(variables, table, { guard: hasLabelFilter, label: 'label' });
}
