<script>
import { GlToastMixin } from '@gitlab/ui';
import { InternalEvents } from '~/tracking';
import { s__, sprintf } from '~/locale';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { createAlert } from '~/alert';
import { confirmAction } from '~/lib/utils/confirm_via_gl_modal/confirm_via_gl_modal';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import { TYPENAME_NAMESPACE } from '~/graphql_shared/constants';
import getSecurityAttributesQuery from '../../graphql/security_attributes.query.graphql';
import createSecurityCategoryMutation from '../../graphql/security_category_create.mutation.graphql';
import updateSecurityCategoryMutation from '../../graphql/security_category_update.mutation.graphql';
import deleteSecurityCategoryMutation from '../../graphql/security_category_delete.mutation.graphql';
import createSecurityAttributesMutation from '../../graphql/security_attributes_create.mutation.graphql';
import updateSecurityAttributeMutation from '../../graphql/security_attribute_update.mutation.graphql';
import deleteSecurityAttributeMutation from '../../graphql/security_attribute_delete.mutation.graphql';
import CategoryList from './category_list.vue';
import CategoryForm from './category_form.vue';
import AttributeDrawer from './attribute_drawer.vue';
import { defaultCategory } from './constants';

export default {
  name: 'ConfigureAttributes',
  components: {
    CategoryList,
    CategoryForm,
    AttributeDrawer,
  },
  mixins: [InternalEvents.mixin(), GlToastMixin],
  inject: ['groupFullPath', 'namespaceId'],
  data() {
    return {
      group: {
        securityCategories: [],
      },
      selectedCategory: null,
      unsavedAttributes: [],
    };
  },
  apollo: {
    group: {
      query: getSecurityAttributesQuery,
      variables() {
        return {
          fullPath: this.groupFullPath,
        };
      },
      fetchPolicy: 'no-cache',
      nextFetchPolicy: 'no-cache',
      result({ data }) {
        if (!this.selectedCategory && data.group.securityCategories.length) {
          this.selectCategory(data.group.securityCategories[0]);
        }
      },
    },
  },
  computed: {
    graphqlNamespaceId() {
      return convertToGraphQLId(TYPENAME_NAMESPACE, this.namespaceId);
    },
  },
  mounted() {
    this.trackEvent('view_group_security_attributes');
  },
  methods: {
    selectCategory(category) {
      this.selectedCategory = {
        ...defaultCategory,
        ...category,
      };
      this.unsavedAttributes = [];
    },
    openDrawer(mode, item) {
      this.$refs.attributeDrawer.open(mode, item);
    },
    editAttribute(attribute) {
      this.openDrawer('edit', attribute);
    },
    addAttribute() {
      this.openDrawer('add');
    },
    async saveCategory(category) {
      try {
        const { id, name, description, multipleSelection } = category;

        // create or update category
        const categoryResult = await this.$apollo.mutate({
          mutation: id ? updateSecurityCategoryMutation : createSecurityCategoryMutation,
          variables: {
            namespaceId: this.graphqlNamespaceId,
            id,
            name,
            description,
            multipleSelection,
          },
        });

        if (categoryResult.data) {
          if (!id && categoryResult.data.securityCategoryCreate) {
            if (categoryResult.data.securityCategoryCreate.errors.length) {
              throw new Error(categoryResult.data.securityCategoryCreate.errors[0]);
            }

            const createdCategory = categoryResult.data.securityCategoryCreate.securityCategory;

            // save unsaved attributes now that we have category id
            if (this.unsavedAttributes.length) {
              const attributesResult = await this.$apollo.mutate({
                mutation: createSecurityAttributesMutation,
                variables: {
                  namespaceId: this.graphqlNamespaceId,
                  categoryId: createdCategory.id,
                  attributes: this.unsavedAttributes,
                },
              });
              if (attributesResult.data) {
                this.selectedCategory = {
                  ...createdCategory,
                  securityAttributes:
                    attributesResult.data.securityAttributeCreate.securityAttributes,
                };
                this.unsavedAttributes = [];
              }
            } else {
              this.selectedCategory = createdCategory;
            }
          }
          this.$apollo.queries.group.refetch();
          this.$toast.show(s__('SecurityAttributes|Category saved'));
        }
      } catch (error) {
        Sentry.captureException(error);
        createAlert({
          message:
            error.message ||
            s__('SecurityAttributes|An error has occurred while saving the security category.'),
        });
      }
    },
    async deleteCategory(category) {
      try {
        // confirm via gl-modal
        const confirmed = await confirmAction(
          sprintf(
            s__(
              'SecurityAttributes|Deleting the "%{categoryName}" Security Attribute category will permanently remove it and all its attributes. Projects using attributes from this category will lose those attributes. This action cannot be undone.',
            ),
            {
              categoryName: category.name,
            },
          ),
          {
            title: s__('SecurityAttributes|Delete category?'),
            primaryBtnText: s__('SecurityAttributes|Delete category'),
            primaryBtnVariant: 'danger',
          },
        );
        if (!confirmed) {
          return;
        }

        // delete category
        const result = await this.$apollo.mutate({
          mutation: deleteSecurityCategoryMutation,
          variables: {
            id: category.id,
          },
        });
        if (result.data) {
          this.selectedCategory = null;
          this.$apollo.queries.group.refetch();
          this.$toast.show(s__('SecurityAttributes|Category deleted'));
        }
      } catch (error) {
        Sentry.captureException(error);
        createAlert({
          message: s__(
            'SecurityAttributes|An error has occurred while deleting the security category.',
          ),
        });
      }
    },
    async saveAttribute(attribute) {
      try {
        // if category hasn't been saved, queue the attribute to be created later
        if (!this.selectedCategory.id) {
          this.unsavedAttributes.push(attribute);
        }

        // if attribute has no id, create a new attribute
        else if (!attribute.id) {
          await this.$apollo
            .mutate({
              mutation: createSecurityAttributesMutation,
              variables: {
                namespaceId: this.graphqlNamespaceId,
                categoryId: this.selectedCategory.id,
                attributes: [attribute],
              },
            })
            .then(({ data }) => {
              if (data.securityAttributeCreate.errors.length) {
                throw new Error(data.securityAttributeCreate.errors[0]);
              }
              // append new attribute to local array
              this.selectedCategory.securityAttributes = [
                ...this.selectedCategory.securityAttributes,
                ...data.securityAttributeCreate.securityAttributes,
              ];
              this.$apollo.queries.group.refetch();
              this.$toast.show(s__('SecurityAttributes|Attribute created'));
            });
        }

        // if attribute has id, update the existing attribute
        else {
          await this.$apollo
            .mutate({
              mutation: updateSecurityAttributeMutation,
              variables: {
                ...attribute,
              },
            })
            .then(({ data }) => {
              if (data.securityAttributeUpdate.errors.length) {
                throw new Error(data.securityAttributeUpdate.errors[0]);
              }
              const updatedAttribute = data.securityAttributeUpdate.securityAttribute;
              // update attribute in local array
              this.selectedCategory.securityAttributes =
                this.selectedCategory.securityAttributes.map((existingAttribute) => {
                  if (existingAttribute.id === updatedAttribute.id) {
                    return updatedAttribute;
                  }
                  return existingAttribute;
                });
              this.$apollo.queries.group.refetch();
              this.$toast.show(s__('SecurityAttributes|Attribute updated'));
            });
        }
      } catch (error) {
        Sentry.captureException(error);
        createAlert({
          message:
            error?.message ||
            s__('SecurityAttributes|An error has occurred while saving the security attribute.'),
        });
      }
    },
    async deleteAttribute(deletedAttribute) {
      if (!deletedAttribute.id) {
        this.unsavedAttributes.splice(this.unsavedAttributes.indexOf(deletedAttribute), 1);
        return;
      }
      try {
        // confirm via gl-modal
        const confirmed = await confirmAction(
          sprintf(
            s__(
              'SecurityAttributes|Deleting the "%{attributeName}" Security Attribute will permanently remove it from the "%{categoryName}" category and any projects where it\'s applied. This action cannot be undone.',
            ),
            {
              attributeName: deletedAttribute.name,
              categoryName: this.selectedCategory.name,
            },
          ),
          {
            title: s__('SecurityAttributes|Delete security attribute?'),
            primaryBtnText: s__('SecurityAttributes|Delete security attribute'),
            primaryBtnVariant: 'danger',
          },
        );
        if (!confirmed) {
          return;
        }

        // delete attribute
        const result = await this.$apollo.mutate({
          mutation: deleteSecurityAttributeMutation,
          variables: {
            id: deletedAttribute.id,
          },
        });
        if (result.data) {
          // remove attribute from local array
          this.selectedCategory.securityAttributes =
            this.selectedCategory.securityAttributes.filter(
              (attribute) => attribute.id !== deletedAttribute.id,
            );
          this.$apollo.queries.group.refetch();
          this.$toast.show(s__('SecurityAttributes|Attribute deleted'));
        }
      } catch (error) {
        Sentry.captureException(error);
        createAlert({
          message: s__(
            'SecurityAttributes|An error has occurred while deleting the security attribute.',
          ),
        });
      }
    },
  },
};
</script>
<template>
  <div class="gl-border-t gl-flex">
    <div class="gl-border-r gl-w-1/4 gl-min-w-20 gl-p-5">
      <category-list
        :security-categories="group.securityCategories"
        :selected-category="selectedCategory"
        @select-category="selectCategory"
      />
    </div>
    <div class="gl-w-3/4">
      <category-form
        :selected-category="selectedCategory"
        :unsaved-attributes="unsavedAttributes"
        @add-attribute="addAttribute"
        @edit-attribute="editAttribute"
        @save-category="saveCategory"
        @delete-category="deleteCategory"
        @delete-attribute="deleteAttribute"
      />
      <attribute-drawer
        ref="attributeDrawer"
        @save-attribute="saveAttribute"
        @delete-attribute="deleteAttribute"
      />
    </div>
  </div>
</template>
