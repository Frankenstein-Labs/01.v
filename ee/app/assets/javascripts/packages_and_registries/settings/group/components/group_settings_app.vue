<script>
import CeGroupSettingsApp from '~/packages_and_registries/settings/group/components/group_settings_app.vue';
import VirtualRegistriesSetting from 'ee_component/packages_and_registries/settings/group/components/virtual_registries_setting.vue';

export default {
  name: 'GroupSettingsAppEE',
  components: {
    CeGroupSettingsApp,
    VirtualRegistriesSetting,
  },
  inject: ['shouldRenderVirtualRegistriesSetting'],
};
</script>

<template>
  <ce-group-settings-app>
    <template #virtual-registries-setting="{ handleSuccess, handleError }">
      <virtual-registries-setting
        v-if="shouldRenderVirtualRegistriesSetting"
        id="virtual-registries-setting"
        @success="handleSuccess"
        @error="handleError"
      />
    </template>
  </ce-group-settings-app>
</template>
