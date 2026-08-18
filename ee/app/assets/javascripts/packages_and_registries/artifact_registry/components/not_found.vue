<script>
import emptyStateSvgPath from '@gitlab/svgs/dist/illustrations/error/error-404-lg.svg';
import { GlEmptyState } from '@gitlab/ui';
import { s__ } from '~/locale';
import { PAGE_NOT_FOUND_TITLE } from '../constants';

export default {
  name: 'ArtifactRegistryRepositoriesNotFound',
  components: {
    GlEmptyState,
  },
  i18n: {
    title: PAGE_NOT_FOUND_TITLE,
    description: s__('404|Make sure the address is correct and the page has not moved.'),
  },
  emptyStateSvgPath,
};
</script>

<template>
  <gl-empty-state
    :svg-path="$options.emptyStateSvgPath"
    :title="$options.i18n.title"
    :description="$options.i18n.description"
    :header-level="1"
  />
</template>
