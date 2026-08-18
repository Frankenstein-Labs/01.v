import { __ } from '~/locale';
import { BUILD_TAB_ACTIONS, BUILD_TAB_RULES, BUILD_TAB_TRIGGERS } from '../constants';

export const TABS = [
  {
    id: BUILD_TAB_TRIGGERS,
    single: true,
    selectionKey: 'trigger',
    configKey: 'triggerConfig',
    joiner: __('OR'),
  },
  {
    id: BUILD_TAB_RULES,
    selectionKey: 'rules',
    configKey: 'ruleConfigs',
    joiner: __('AND'),
  },
  {
    id: BUILD_TAB_ACTIONS,
    selectionKey: 'actions',
    configKey: 'actionConfigs',
    joiner: __('AND'),
  },
];
