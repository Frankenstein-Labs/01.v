# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Gfm::ReferenceRewriter, feature_category: :markdown do
  describe '#rewrite with table syntax' do
    using RSpec::Parameterized::TableSyntax

    let_it_be(:parent_group1) { create(:group, path: "parent-group-one") }
    let_it_be(:parent_group2) { create(:group, path: "parent-group-two") }
    let_it_be(:user) { create(:user) }

    let_it_be(:source_project) { create(:project, path: 'old-project', group: parent_group1) }
    let_it_be(:target_project1) { create(:project, path: 'new-project', group: parent_group1) }
    let_it_be(:target_project2) { create(:project, path: 'new-project', group: parent_group2) }
    let_it_be(:source_group) { create(:group, path: 'old-group', parent: parent_group1) }
    let_it_be(:target_group1) { create(:group, path: 'new-group', parent: parent_group1) }
    let_it_be(:target_group2) { create(:group, path: 'new-group', parent: parent_group2) }

    let_it_be(:work_item_project_first) { create(:issue, project: source_project) }
    let_it_be(:work_item_group_first) { create(:issue, :group_level, namespace: source_group) }

    let_it_be(:merge_request) { create(:merge_request, source_project: source_project) }

    let_it_be(:project_label) { create(:label, id: 123, name: 'pr label1', project: source_project) }
    let_it_be(:parent_group_label) { create(:group_label, id: 321, name: 'gr label1', group: parent_group1) }

    let_it_be(:project_milestone) { create(:milestone, title: 'project milestone', project: source_project) }
    let_it_be(:parent_group_milestone) { create(:milestone, title: 'group milestone', group: parent_group1) }

    before_all do
      parent_group1.add_reporter(user)
      parent_group2.add_reporter(user)
    end

    before do
      stub_licensed_features(epics: true)
    end

    context 'with source as Project and target as Project within same parent group' do
      let_it_be(:source_parent) { source_project }  # 'parent-group-one/old-project'
      let_it_be(:target_parent) { target_project1 } # 'parent-group-one/new-project'

      where(:source_text, :destination_text) do
        # group level work item reference
        'ref parent-group-one/old-group#1'   | 'ref parent-group-one/old-group#1'
        'ref parent-group-one/old-group#1+'  | 'ref parent-group-one/old-group#1+'
        'ref parent-group-one/old-group#1+s' | 'ref parent-group-one/old-group#1+s'
      end

      with_them do
        it_behaves_like 'rewrites references correctly'
      end
    end

    context 'with source as Project and target as Project within different parent groups' do
      let_it_be(:source_parent) { source_project }  # 'parent-group-one/old-project'
      let_it_be(:target_parent) { target_project2 } # 'parent-group-two/new-project'

      where(:source_text, :destination_text) do
        # group level work item reference
        'ref parent-group-one/old-group#1'   | 'ref parent-group-one/old-group#1'
        'ref parent-group-one/old-group#1+'  | 'ref parent-group-one/old-group#1+'
        'ref parent-group-one/old-group#1+s' | 'ref parent-group-one/old-group#1+s'
      end

      with_them do
        it_behaves_like 'rewrites references correctly'
      end
    end

    context 'with source as Project and target as Group within same parent group' do
      let_it_be(:source_parent) { source_project } # 'parent-group-one/old-project'
      let_it_be(:target_parent) { target_group1 }  # 'parent-group-one/new-group'

      where(:source_text, :destination_text) do
        # group level work item reference
        'ref parent-group-one/old-group#1'   | 'ref parent-group-one/old-group#1'
        'ref parent-group-one/old-group#1+'  | 'ref parent-group-one/old-group#1+'
        'ref parent-group-one/old-group#1+s' | 'ref parent-group-one/old-group#1+s'
      end

      with_them do
        it_behaves_like 'rewrites references correctly'
      end
    end

    context 'with source as Project and target as Group within different parent groups' do
      let_it_be(:source_parent) { source_project } # 'parent-group-one/old-project'
      let_it_be(:target_parent) { target_group2 }  # 'parent-group-two/new-group'

      where(:source_text, :destination_text) do
        # group level work item reference
        'ref parent-group-one/old-group#1'   | 'ref parent-group-one/old-group#1'
        'ref parent-group-one/old-group#1+'  | 'ref parent-group-one/old-group#1+'
        'ref parent-group-one/old-group#1+s' | 'ref parent-group-one/old-group#1+s'
      end

      with_them do
        it_behaves_like 'rewrites references correctly'
      end
    end

    context 'with source as Group and target as Project within same parent groups' do
      let_it_be(:source_parent) { source_group }    # 'parent-group-one/old-group'
      let_it_be(:target_parent) { target_project1 } # 'parent-group-one/new-project'

      where(:source_text, :destination_text) do
        # project level work item reference
        'ref parent-group-one/old-project#1'                   | 'ref parent-group-one/old-project#1'
        'ref parent-group-one/old-project#1+'                  | 'ref parent-group-one/old-project#1+'
        'ref parent-group-one/old-project#1+s'                 | 'ref parent-group-one/old-project#1+s'
        # group level work item reference
        'ref #1'                                               | 'ref parent-group-one/old-group#1'
        'ref #1+'                                              | 'ref parent-group-one/old-group#1+'
        'ref #1+s'                                             | 'ref parent-group-one/old-group#1+s'
        # merge request reference
        'ref parent-group-one/old-project!1'                   | 'ref parent-group-one/old-project!1'
        'ref parent-group-one/old-project!1+'                  | 'ref parent-group-one/old-project!1+'
        'ref parent-group-one/old-project!1+s'                 | 'ref parent-group-one/old-project!1+s'
        # project label reference
        'ref parent-group-one/old-project~123'                 | 'ref parent-group-one/old-project~123'
        'ref parent-group-one/old-project~"pr label1"'         | 'ref parent-group-one/old-project~123'
        # group level label reference
        'ref ~321'                                             | 'ref parent-group-one/old-group~321'
        'ref ~"gr label1"'                                     | 'ref parent-group-one/old-group~321'
        # project level milestone reference
        'ref parent-group-one/old-project%"project milestone"' | 'ref /parent-group-one/old-project%"project milestone"'
        # group level milestone reference
        'ref %"group milestone"'                               | 'ref /parent-group-one%"group milestone"'
      end

      with_them do
        it_behaves_like 'rewrites references correctly'
      end
    end

    context 'with source as Group and target as Project within different parent groups' do
      let_it_be(:source_parent) { source_group }    # 'parent-group-one/old-group'
      let_it_be(:target_parent) { target_project2 } # 'parent-group-two/new-project'

      where(:source_text, :destination_text) do
        # project level work item reference
        'ref parent-group-one/old-project#1'                   | 'ref parent-group-one/old-project#1'
        'ref parent-group-one/old-project#1+'                  | 'ref parent-group-one/old-project#1+'
        'ref parent-group-one/old-project#1+s'                 | 'ref parent-group-one/old-project#1+s'
        # group level work item reference
        'ref #1'                                               | 'ref parent-group-one/old-group#1'
        'ref #1+'                                              | 'ref parent-group-one/old-group#1+'
        'ref #1+s'                                             | 'ref parent-group-one/old-group#1+s'
        # merge request reference
        'ref parent-group-one/old-project!1'                   | 'ref parent-group-one/old-project!1'
        'ref parent-group-one/old-project!1+'                  | 'ref parent-group-one/old-project!1+'
        'ref parent-group-one/old-project!1+s'                 | 'ref parent-group-one/old-project!1+s'
        # project label reference
        'ref parent-group-one/old-project~123'                 | 'ref parent-group-one/old-project~123'
        'ref parent-group-one/old-project~"pr label1"'         | 'ref parent-group-one/old-project~123'
        # group level label reference
        'ref ~321'                                             | 'ref parent-group-one/old-group~321'
        'ref ~"gr label1"'                                     | 'ref parent-group-one/old-group~321'
        # project level milestone reference
        'ref parent-group-one/old-project%"project milestone"' | 'ref /parent-group-one/old-project%"project milestone"'
        # group level milestone reference
        'ref %"group milestone"'                               | 'ref /parent-group-one%"group milestone"'
      end

      with_them do
        it_behaves_like 'rewrites references correctly'
      end
    end

    context 'with source as Group and target as Group within same parent groups' do
      let_it_be(:source_parent) { source_group }  # 'parent-group-one/old-group'
      let_it_be(:target_parent) { target_group1 } # 'parent-group-one/new-group'

      where(:source_text, :destination_text) do
        # project level work item reference
        'ref parent-group-one/old-project#1'                   | 'ref parent-group-one/old-project#1'
        'ref parent-group-one/old-project#1+'                  | 'ref parent-group-one/old-project#1+'
        'ref parent-group-one/old-project#1+s'                 | 'ref parent-group-one/old-project#1+s'
        # group level work item reference
        'ref #1'                                               | 'ref parent-group-one/old-group#1'
        'ref #1+'                                              | 'ref parent-group-one/old-group#1+'
        'ref #1+s'                                             | 'ref parent-group-one/old-group#1+s'
        # merge request reference
        'ref parent-group-one/old-project!1'                   | 'ref parent-group-one/old-project!1'
        'ref parent-group-one/old-project!1+'                  | 'ref parent-group-one/old-project!1+'
        'ref parent-group-one/old-project!1+s'                 | 'ref parent-group-one/old-project!1+s'
        # project label reference
        'ref parent-group-one/old-project~123'                 | 'ref parent-group-one/old-project~123'
        'ref parent-group-one/old-project~"pr label1"'         | 'ref parent-group-one/old-project~123'
        # group level label reference
        'ref ~321'                                             | 'ref parent-group-one/old-group~321'
        'ref ~"gr label1"'                                     | 'ref parent-group-one/old-group~321'
        # project level milestone reference
        'ref parent-group-one/old-project%"project milestone"' | 'ref /parent-group-one/old-project%"project milestone"'
        # group level milestone reference
        'ref %"group milestone"'                               | 'ref /parent-group-one%"group milestone"'
      end

      with_them do
        it_behaves_like 'rewrites references correctly'
      end
    end

    context 'with source as Group and target as Group within different parent groups' do
      let_it_be(:source_parent) { source_group }  # 'parent-group-one/old-group'
      let_it_be(:target_parent) { target_group2 } # 'parent-group-two/new-group'

      where(:source_text, :destination_text) do
        # project level work item reference
        'ref parent-group-one/old-project#1'                   | 'ref parent-group-one/old-project#1'
        'ref parent-group-one/old-project#1+'                  | 'ref parent-group-one/old-project#1+'
        'ref parent-group-one/old-project#1+s'                 | 'ref parent-group-one/old-project#1+s'
        # group level work item reference
        'ref #1'                                               | 'ref parent-group-one/old-group#1'
        'ref #1+'                                              | 'ref parent-group-one/old-group#1+'
        'ref #1+s'                                             | 'ref parent-group-one/old-group#1+s'
        # merge request reference
        'ref parent-group-one/old-project!1'                   | 'ref parent-group-one/old-project!1'
        'ref parent-group-one/old-project!1+'                  | 'ref parent-group-one/old-project!1+'
        'ref parent-group-one/old-project!1+s'                 | 'ref parent-group-one/old-project!1+s'
        # project label reference
        'ref parent-group-one/old-project~123'                 | 'ref parent-group-one/old-project~123'
        'ref parent-group-one/old-project~"pr label1"'         | 'ref parent-group-one/old-project~123'
        # group level label reference
        'ref ~321'                                             | 'ref parent-group-one/old-group~321'
        'ref ~"gr label1"'                                     | 'ref parent-group-one/old-group~321'
        # project level milestone reference
        'ref parent-group-one/old-project%"project milestone"' | 'ref /parent-group-one/old-project%"project milestone"'
        # group level milestone reference
        'ref %"group milestone"'                               | 'ref /parent-group-one%"group milestone"'
      end

      with_them do
        it_behaves_like 'rewrites references correctly'
      end
    end

    context 'with invalid references' do
      let_it_be(:source_parent) { source_project }
      let_it_be(:target_parent) { target_project1 }

      where(:text_with_reference) do
        [
          'ref parent-group-one/old-group#1/designs[homescreen.jpg]',
          'ref /parent-group-one/old-group#1/designs[homescreen.jpg]',
          # non-existing group level work item reference
          'ref parent-group-one/old-group#12321',
          'ref parent-group-one/old-group#12321+',
          'ref parent-group-one/old-group#12321+s',
          'ref /parent-group-one/old-group#12321',
          'ref /parent-group-one/old-group#12321+',
          'ref /parent-group-one/old-group#12321+s',

          # epic reference
          # group level non-existing epic reference
          'ref parent-group-one/old-group&12321',
          'ref parent-group-one/old-group&12321+',
          'ref parent-group-one/old-group&12321+s',
          'ref /parent-group-one/old-group&12321',
          'ref /parent-group-one/old-group&12321+',
          'ref /parent-group-one/old-group&12321+s',

          # project level epic reference
          'ref parent-group-one/old-project&12321',
          'ref parent-group-one/old-project&12321+',
          'ref parent-group-one/old-project&12321+s',
          'ref /parent-group-one/old-project&12321',
          'ref /parent-group-one/old-project&12321+',
          'ref /parent-group-one/old-project&12321+s',

          # vulnerability reference
          'ref [vulnerability:parent-group-one/old-project/123]',
          'ref [vulnerability:parent-group-one/123]',
          'ref [vulnerability:parent-group-one/old-group/123]',
          'ref [vulnerability:/parent-group-one/old-project/123]',
          'ref [vulnerability:/parent-group-one/123]',
          'ref [vulnerability:/parent-group-one/old-group/123]'
        ]
      end

      with_them do
        it_behaves_like 'does not raise errors on invalid references'
      end
    end
  end
end
