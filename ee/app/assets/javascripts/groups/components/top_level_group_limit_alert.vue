<script>
import { GlAlert } from '@gitlab/ui';
import { helpPagePath } from '~/helpers/help_page_helper';

export default {
  name: 'TopLevelGroupLimitAlert',
  components: {
    GlAlert,
  },
  freeUserLimitHelpPath: helpPagePath('user/free_user_limit', { anchor: 'top-level-group-limits' }),
};
</script>

<template>
  <gl-alert
    ref="newTopLevelAlert"
    data-testid="new-top-level-alert"
    variant="warning"
    :title="__('You have reached the limit of three top-level groups')"
    :primary-button-text="__('Learn more about free user limits')"
    :primary-button-link="$options.freeUserLimitHelpPath"
    >{{
      __(
        'To create another group, reduce the number of groups you have, or upgrade to a paid tier.',
      )
    }}</gl-alert
  >
</template>
