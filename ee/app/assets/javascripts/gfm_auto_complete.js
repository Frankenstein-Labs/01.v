import $ from 'jquery';
import { DEFAULT_DEBOUNCE_AND_THROTTLE_MS } from '~/lib/utils/constants';
import '~/lib/utils/jquery_at_who';
import GfmAutoComplete, {
  showAndHideHelper,
  escape,
  setupSubcommands,
  setupQuotedCompletion,
} from '~/gfm_auto_complete';
import { s__ } from '~/locale';
import { spriteIcon } from '~/lib/utils/common_utils';
import { getAdaptiveStatusColor } from '~/lib/utils/color_utils';
import { availableStatuses } from '~/graphql_shared/issuable_client_state';
import { MERGE_REQUEST_NOTEABLE_TYPE } from '~/notes/constants';

/**
 * This is added to keep the export parity with the CE counterpart.
 *
 * Some modules import `defaultAutocompleteConfig` or `membersBeforeSave`
 * which will be undefined if not exported from here in EE.
 */
export {
  escape,
  defaultAutocompleteConfig,
  getEnableGFMType,
  membersBeforeSave,
  highlighter,
  CONTACT_STATE_ACTIVE,
  CONTACTS_ADD_COMMAND,
  CONTACTS_REMOVE_COMMAND,
} from '~/gfm_auto_complete';

const EPICS_ALIAS = 'epics';
const EPICS_ALTERNATIVE_ALIAS = 'epicsalternative';
const ITERATIONS_ALIAS = 'iterations';
const VULNERABILITIES_ALIAS = 'vulnerabilities';

export const Q_ISSUE_SUB_COMMANDS = {
  dev: {
    header: s__('AmazonQ|dev'),
    description: s__('AmazonQ|Create a merge request to incorporate Amazon Q suggestions'),
  },
  transform: {
    header: s__('AmazonQ|transform'),
    description: s__('AmazonQ|Upgrade Java Maven application to Java 17'),
  },
};

export const Q_MERGE_REQUEST_SUB_COMMANDS = {
  dev: {
    header: s__('AmazonQ|dev'),
    description: s__('AmazonQ|Apply changes to this merge request based on the comments'),
  },
  review: {
    header: s__('AmazonQ|review'),
    description: s__('AmazonQ|Review merge request for code quality and security issues'),
  },
};

export const Q_MERGE_REQUEST_DIFF_SUB_COMMANDS = {
  ...Q_MERGE_REQUEST_SUB_COMMANDS,
};

const getQSubCommands = ($input) => {
  if ($input.data('noteableType') === MERGE_REQUEST_NOTEABLE_TYPE) {
    const canSuggest = $input.data('canSuggest');
    if (canSuggest) {
      return Q_MERGE_REQUEST_DIFF_SUB_COMMANDS;
    }
    return Q_MERGE_REQUEST_SUB_COMMANDS;
  }

  return Q_ISSUE_SUB_COMMANDS;
};

GfmAutoComplete.Epics = {
  alternativeReferenceInsertTemplateFunction(value) {
    // eslint-disable-next-line no-template-curly-in-string
    return value.reference || '&${id}';
  },
};

GfmAutoComplete.Iterations = {
  templateFunction({ id, title }) {
    return `<li><small>*iteration:${id}</small> ${escape(title)}</li>`;
  },
};

GfmAutoComplete.Statuses = {
  templateFunction({ id, name, color, iconName }) {
    const icon = spriteIcon(iconName, 's12 gl-mr-2 gl-fill-current', getAdaptiveStatusColor(color));
    return `<li data-id="${id}">${icon}<span>${escape(name)}</span></li>`;
  },
};

class GfmAutoCompleteEE extends GfmAutoComplete {
  setupAtWho($input) {
    if (this.enableMap.epics) {
      this.setupAutoCompleteEpics($input, this.getDefaultCallbacks());
    }

    if (this.enableMap.epicsAlternative) {
      this.setupAutoCompleteEpicsAlternative($input, this.getDefaultCallbacks());
    }

    if (this.enableMap.iterations) {
      this.setupAutoCompleteIterations($input, this.getDefaultCallbacks());
    }

    if (this.enableMap.vulnerabilities) {
      this.setupAutoCompleteVulnerabilities($input, this.getDefaultCallbacks());
    }

    if (this.enableMap.statuses) {
      this.setupQuotedCompletions($input);
    }

    super.setupAtWho($input);
  }

  loadSubcommands($input, data) {
    if (data.some((c) => c.name === 'q')) {
      setupSubcommands($input, 'q', getQSubCommands($input));
    }

    super.loadSubcommands($input, data);
  }

  // eslint-disable-next-line class-methods-use-this
  setupAutoCompleteEpics = ($input, defaultCallbacks) => {
    $input.atwho({
      at: '&',
      alias: EPICS_ALIAS,
      searchKey: 'search',
      displayTpl(value) {
        let tmpl = GfmAutoComplete.Loading.template;
        if (value.title != null) {
          tmpl = GfmAutoComplete.Issues.templateFunction(value);
        }
        return tmpl;
      },
      data: GfmAutoComplete.defaultLoadingData,
      insertTpl: GfmAutoComplete.Issues.insertTemplateFunction,
      skipSpecialCharacterTest: true,
      callbacks: {
        ...defaultCallbacks,
        beforeSave(merges) {
          return $.map(merges, (m) => {
            if (m.title == null) {
              return m;
            }
            return {
              id: m.iid,
              reference: m.reference,
              title: m.title,
              search: `${m.iid} ${m.title}`,
            };
          });
        },
      },
    });
    showAndHideHelper($input, EPICS_ALIAS);
  };

  // eslint-disable-next-line class-methods-use-this
  setupAutoCompleteEpicsAlternative = ($input, defaultCallbacks) => {
    $input.atwho({
      at: '[epic:',
      alias: EPICS_ALTERNATIVE_ALIAS,
      delay: DEFAULT_DEBOUNCE_AND_THROTTLE_MS,
      searchKey: 'search',
      displayTpl(value) {
        let tmpl = GfmAutoComplete.Loading.template;
        if (value.title != null) {
          tmpl = GfmAutoComplete.Issues.templateFunction(value);
        }
        return tmpl;
      },
      data: GfmAutoComplete.defaultLoadingData,
      insertTpl: GfmAutoComplete.Epics.alternativeReferenceInsertTemplateFunction,
      skipSpecialCharacterTest: true,
      callbacks: {
        ...defaultCallbacks,
        beforeSave(epics) {
          return $.map(epics, (e) => {
            if (e.title == null) {
              return e;
            }
            return {
              id: e.iid,
              reference: e.reference,
              title: e.title,
              search: `${e.iid} ${e.title}`,
            };
          });
        },
      },
    });
    showAndHideHelper($input, EPICS_ALTERNATIVE_ALIAS);
  };

  // eslint-disable-next-line class-methods-use-this
  setupAutoCompleteIterations = ($input, defaultCallbacks) => {
    $input.atwho({
      at: '*iteration:',
      alias: ITERATIONS_ALIAS,
      searchKey: 'search',
      displayTpl(value) {
        let tmpl = GfmAutoComplete.Loading.template;
        if (value.id != null) {
          tmpl = GfmAutoComplete.Iterations.templateFunction(value);
        }
        return tmpl;
      },
      data: GfmAutoComplete.defaultLoadingData,
      // eslint-disable-next-line no-template-curly-in-string
      insertTpl: '${atwho-at}${id}',
      skipSpecialCharacterTest: true,
      callbacks: {
        ...defaultCallbacks,
        beforeSave(merges) {
          return $.map(merges, (m) => {
            if (m.id == null) {
              return m;
            }

            return {
              id: m.id,
              title: m.title,
              search: `${m.id} ${m.title}`,
            };
          });
        },
      },
    });
    showAndHideHelper($input, ITERATIONS_ALIAS);
  };

  // eslint-disable-next-line class-methods-use-this
  setupAutoCompleteVulnerabilities = ($input, defaultCallbacks) => {
    $input.atwho({
      at: '[vulnerability:',
      suffix: ']',
      alias: VULNERABILITIES_ALIAS,
      delay: DEFAULT_DEBOUNCE_AND_THROTTLE_MS,
      searchKey: 'search',
      displayTpl(value) {
        let tmpl = GfmAutoComplete.Loading.template;
        if (value.title != null) {
          tmpl = GfmAutoComplete.Issues.templateFunction(value);
        }
        return tmpl;
      },
      data: GfmAutoComplete.defaultLoadingData,
      insertTpl: GfmAutoComplete.Issues.insertTemplateFunction,
      skipSpecialCharacterTest: true,
      callbacks: {
        ...defaultCallbacks,
        beforeSave(merges) {
          return merges.map((m) => {
            if (m.title == null) {
              return m;
            }
            return {
              id: m.id,
              title: m.title,
              reference: m.reference,
              search: `${m.id} ${m.title}`,
            };
          });
        },
      },
    });
    showAndHideHelper($input, VULNERABILITIES_ALIAS);
  };
}

// eslint-disable-next-line @gitlab/no-hardcoded-urls -- False positive, not a URL
setupQuotedCompletion('/status', {
  enableMapKey: 'statuses',
  templateFunction(value) {
    if (value.id == null) {
      return GfmAutoComplete.Loading.template;
    }
    return GfmAutoComplete.Statuses.templateFunction(value);
  },
  beforeSave(merges) {
    return merges.map((m) => {
      if (m.name == null) {
        return m;
      }
      return {
        id: m.id,
        name: m.name,
        search: `${m.id} ${m.name}`,
      };
    });
  },
  getItems({ workItemFullPath, workItemTypeId }) {
    const statuses = availableStatuses()[workItemFullPath];
    return statuses?.[workItemTypeId] || [];
  },
});

export default GfmAutoCompleteEE;
