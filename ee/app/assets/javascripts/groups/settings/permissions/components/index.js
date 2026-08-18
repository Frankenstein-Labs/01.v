import { initVueApp } from '~/lib/utils/vue3compat/init_vue_app';
import { parseBoolean } from '~/lib/utils/common_utils';
import PlaceholderBypassGroupSetting from './placeholder_bypass_group_setting.vue';

export function initPlaceholderBypassGroupSetting() {
  const el = document.getElementById('group-bypass-placeholder-confirmation-setting');

  if (!el) return null;

  const viewModel = JSON.parse(el.dataset.viewModel);

  const props = {
    isBypassOn: parseBoolean(viewModel.is_bypass_on),
    currentExpiryDate: viewModel.current_expiry_date || null,
    minDate: new Date(viewModel.min_date),
    maxDate: new Date(viewModel.max_date),
    shouldDisableCheckbox: parseBoolean(viewModel.should_disable_checkbox),
  };

  return initVueApp({
    el,
    name: 'PlaceholderBypassGroupSettingRoot',
    component: PlaceholderBypassGroupSetting,
    props,
  });
}
