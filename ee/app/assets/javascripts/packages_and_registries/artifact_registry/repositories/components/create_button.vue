<script>
import { GlDisclosureDropdown } from '@gitlab/ui';
import { s__ } from '~/locale';
import { REPOSITORY_NEW_HOSTED_ROUTE_NAME } from '../../constants';

export default {
  name: 'ArtifactRegistryCreateButton',
  i18n: {
    // The toggle text is the toggle's accessible name, so it names the object it
    // creates rather than the verb alone: "Create" on its own is not understandable
    // out of context. Mirrors the "New file / project / issue" pattern.
    toggle: s__('ArtifactRegistry|New repository'),
  },
  components: {
    GlDisclosureDropdown,
  },
  // The kind is chosen here rather than in the form, so each kind is its own entry.
  // Hosted is the only one Artifact Registry accepts in Phase 1, so the remote and
  // virtual entries are absent rather than disabled: an entry that cannot lead
  // anywhere is not an affordance. `to` rather than a click handler is what keeps
  // each entry a real link, so it reads and behaves as navigation.
  items: [
    {
      text: s__('ArtifactRegistry|Hosted repository'),
      to: { name: REPOSITORY_NEW_HOSTED_ROUTE_NAME },
    },
  ],
};
</script>

<template>
  <gl-disclosure-dropdown
    variant="confirm"
    placement="bottom-end"
    :toggle-text="$options.i18n.toggle"
    :items="$options.items"
  />
</template>
