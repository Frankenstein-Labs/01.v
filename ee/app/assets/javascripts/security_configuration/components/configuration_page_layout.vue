<script>
import PageHeading from '~/vue_shared/components/page_heading.vue';
import { glSlotsMixin } from '~/lib/utils/vue3compat/gl_slots_mixin';

export default {
  name: 'ConfigurationPageLayout',
  components: {
    PageHeading,
  },
  mixins: [glSlotsMixin],
};
</script>

<template>
  <article>
    <slot name="alert"></slot>

    <page-heading>
      <template v-if="glSlots().heading" #heading>
        <slot name="heading"></slot>
      </template>

      <template v-if="glSlots().description" #description>
        <slot name="description"></slot>
      </template>

      <template v-if="glSlots().actions" #actions>
        <slot name="actions"></slot>
      </template>
    </page-heading>

    <slot></slot>
  </article>
</template>
