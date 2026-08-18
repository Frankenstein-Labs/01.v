import * as Sentry from '~/sentry/sentry_browser_wrapper';
import Api from 'ee/api';
import { ACTIONS } from './actions';
import { RULES } from './rules';
import { TRIGGERS } from './triggers';

export const EMPTY_CATALOGS = Object.freeze({
  triggers: [],
  rules: [],
  actions: [],
});

export const presentable = ({ id, name }, localCatalog) =>
  localCatalog.find((entry) => entry.id === id) ?? {
    id,
    label: name || id,
    description: '',
    icon: 'question-o',
    fields: [],
  };

const toCatalog = async (name, request, localCatalog) => {
  try {
    const { data } = await request();
    const entries = data.filter((remote) => remote?.id);

    // An empty catalog cannot build a policy, so a healthy-but-empty response is
    // as unusable as a failed one.
    if (!entries.length) {
      throw new Error(`Policy Store returned no ${name}`);
    }

    return entries.map((remote) => presentable(remote, localCatalog));
  } catch (error) {
    Sentry.captureException(error, { tags: { policyStoreCatalog: name } });

    throw error;
  }
};

/**
 * Fetches the available triggers, rules and actions from the Policy Store API.
 *
 * The local catalog files supply the presentation (label, description, icon,
 * category, config fields) for the ids the API returns. Each catalog fails
 * independently: a catalog whose request fails or comes back empty resolves as
 * an empty list and its name appears in `failedCatalogs`, while the others keep
 * their entries. Every failure is also reported to Sentry, tagged with the
 * failing catalog. Never rejects.
 *
 * @returns {Promise<{ catalogs: { triggers: Array, rules: Array, actions: Array },
 *   failedCatalogs: string[] }>}
 */
export const fetchCatalogs = async () => {
  const requests = [
    ['triggers', () => Api.getPolicyTriggers(), TRIGGERS],
    ['rules', () => Api.getPolicyRules(), RULES],
    ['actions', () => Api.getPolicyActions(), ACTIONS],
  ];

  const results = await Promise.allSettled(
    requests.map(([name, request, localCatalog]) => toCatalog(name, request, localCatalog)),
  );

  const failedCatalogs = requests
    .filter((request, index) => results[index].status === 'rejected')
    .map(([name]) => name);

  const [triggers, rules, actions] = results.map((result) =>
    result.status === 'fulfilled' ? result.value : [],
  );

  return { catalogs: { triggers, rules, actions }, failedCatalogs };
};
