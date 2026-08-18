<script>
import { GlEmptyState, GlModalDirective } from '@gitlab/ui';
import EMPTY_STATE_SVG from '@gitlab/svgs/dist/illustrations/empty-state/empty-groups-md.svg?url';
import { I18N_EMPTY_STATE_TITLE, I18N_EMPTY_STATE_DESCRIPTION } from '../constants';

export default {
  name: 'DevopsAdoptionEmptyState',
  components: {
    GlEmptyState,
  },
  directives: {
    GlModal: GlModalDirective,
  },
  i18n: {
    title: I18N_EMPTY_STATE_TITLE,
    description: I18N_EMPTY_STATE_DESCRIPTION,
  },
  EMPTY_STATE_SVG,
};
</script>
<template>
  <gl-empty-state
    :title="$options.i18n.title"
    :description="$options.i18n.description"
    :svg-path="$options.EMPTY_STATE_SVG"
  />
</template>
