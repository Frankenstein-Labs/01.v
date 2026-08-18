import { readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { camelCase } from 'lodash-es';
import { captureMissingOperation } from './operation_helpers';

function cloneResponse(response) {
  return JSON.parse(JSON.stringify(response));
}

/**
 * Finds the fixture in `table` whose `matches` predicate accepts `variables`.
 *
 * @param {Object} variables - GraphQL variables from the intercepted MSW request.
 * @param {Array<{matches: Function}>} table - Fixture candidates to search.
 * @param {Object} options
 * @param {Function} options.guard - Returns true if `variables` carries a filter this
 *   table is responsible for; gates whether a non-match is an error.
 * @param {string} options.label - Fixture table name, used only in the error message.
 * @returns {*|undefined} The matching fixture, or `undefined` when no filter applies.
 */
export function matchFixture(variables, table, { guard, label }) {
  const match = table.find((candidate) => candidate.matches(variables));

  if (!match && guard(variables)) {
    const message = `No ${label} fixture matches ${JSON.stringify(
      variables,
    )}. Add one to the ${label} fixture table.`;

    captureMissingOperation(message);

    throw new Error(message);
  }

  return match;
}

export function loadFixturesMap(basePath) {
  const files = readdirSync(basePath).filter((f) => f.endsWith('.json'));
  const map = {};

  files.forEach((file) => {
    const operationName = camelCase(
      file.replace(/\.(query|mutation)\.graphql\.json$/, '').replace(/\.json$/, ''),
    );
    const content = JSON.parse(readFileSync(join(basePath, file), 'utf-8'));
    map[operationName] = content;
  });

  return map;
}

export function buildUpdateResponse({
  baseResponse,
  labelsFixture,
  assigneesFixture,
  milestoneFixture,
  input,
}) {
  const { labelsWidget, assigneesWidget, title } = input;

  if (labelsWidget) {
    const response = cloneResponse(labelsFixture);
    return response;
  }

  if (assigneesWidget) {
    const response = cloneResponse(assigneesFixture);
    return response;
  }

  if (title) {
    const response = cloneResponse(baseResponse);
    response.data.workItemUpdate.workItem.title = title;
    response.data.workItemUpdate.workItem.titleHtml = title;
    return response;
  }

  if (input.confidential !== undefined) {
    const response = cloneResponse(baseResponse);
    response.data.workItemUpdate.workItem.confidential = input.confidential;
    return response;
  }

  if (input.milestoneWidget) {
    return cloneResponse(milestoneFixture);
  }

  if (input.startAndDueDateWidget) {
    const response = cloneResponse(baseResponse);
    const { widgets } = response.data.workItemUpdate.workItem;
    const dateWidget = widgets.find((w) => w.type === 'START_AND_DUE_DATE');
    if (dateWidget) {
      Object.assign(dateWidget, {
        startDate: input.startAndDueDateWidget.startDate || null,
        dueDate: input.startAndDueDateWidget.dueDate || null,
        isFixed: input.startAndDueDateWidget.isFixed ?? dateWidget.isFixed,
      });
    }
    return response;
  }

  return cloneResponse(baseResponse);
}

export function getFirstWorkItem(listFixture) {
  const namespace = listFixture.data.namespace || listFixture.data.project;
  return namespace.workItems.nodes[0];
}

export function getLabelsFromFixture(labelsFixture) {
  const namespace = labelsFixture.data.namespace || labelsFixture.data.project;
  return namespace.labels.nodes;
}

export function getUsersFromFixture(usersFixture) {
  const namespace = usersFixture.data.namespace || usersFixture.data.project;
  return namespace.users || namespace.autocompleteUsers;
}
