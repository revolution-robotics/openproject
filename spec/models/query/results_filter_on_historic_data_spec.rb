#-- copyright
# OpenProject is an open source project management software.
# Copyright (C) 2012-2022 the OpenProject GmbH
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#
# OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
# Copyright (C) 2006-2013 Jean-Philippe Lang
# Copyright (C) 2010-2013 the ChiliProject Team
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# See COPYRIGHT and LICENSE files for more details.
#++

require 'spec_helper'

describe ::Query::Results, 'Filter on historic data', type: :model, with_mail: false do
  let(:historic_time) { "2022-08-01".to_datetime }
  let(:pre_historic_time) { historic_time - 1.day }
  let(:recent_time) { 1.hour.ago }
  let!(:work_package) do
    new_work_package = create :work_package, description: "This is the original description of the work package", project: project_1
    new_work_package.update_columns created_at: historic_time
    new_work_package.journals.first.update_columns created_at: historic_time, updated_at: historic_time
    new_work_package.reload
    new_work_package.update description: "This is the current description of the work package", updated_at: recent_time
    new_work_package.journals.last.update_columns created_at: recent_time, updated_at: recent_time
    new_work_package.reload
    new_work_package
  end

  let(:project_1) { create :project }
  let(:user_1) do
    create(:user,
           firstname: 'user',
           lastname: '1',
           member_in_project: project_1,
           member_with_permissions: [:view_work_packages, :view_file_links])
  end


  describe "[prelims]" do
    specify "the work package has a journal entry with the historic description" do
      expect(work_package.journals.count).to eq 2
      expect(work_package.journals.first.data.description).to eq "This is the original description of the work package"
    end

    specify "the work package has its current description" do
      expect(work_package.description).to eq "This is the current description of the work package"
    end
  end

  describe "#work_packages" do
    let(:query) do
      login_as(user_1)
      build(:query, user: user_1, project: nil).tap do |query|
        query.filters.clear
        query.add_filter 'description', '~', search_term
      end
    end
    let(:results) { query.results }
    subject { results.work_packages }

    describe "filter for description containing 'current'" do
      let(:search_term) { 'current' }
      it "includes the work package matching today" do
        expect(subject).to include work_package
      end
    end

    describe "filter for description containing 'original'" do
      let(:search_term) { 'original' }
      it "does not include the work package matching only in the past" do
        expect(subject).not_to include work_package
      end
    end

    describe "when searching current and historic work packages" do
      before { query.timestamps = [historic_time, Time.zone.now] }

      describe "filter for description containing 'current'" do
        let(:search_term) { 'current' }
        it "includes the work package matching today" do
          expect(subject).to include work_package
        end
      end

      describe "filter for description containing 'original'" do
        let(:search_term) { 'original' }
        it "includes the work package matching in the past" do
          expect(subject).to include work_package
        end
      end
    end

    describe "when searching only historic work packages" do
      before { query.timestamps = [historic_time] }

      describe "filter for description containing 'current'" do
        let(:search_term) { 'current' }
        it "does not include the work package matching only in the past" do
          expect(subject).not_to include work_package
        end
      end

      describe "filter for description containing 'original'" do
        let(:search_term) { 'original' }

        it "includes the work package matching in the past" do
          expect(subject).to include work_package
        end

        it "returns the work packages in their current state" do
          expect(subject.first.description).to eq "This is the current description of the work package"
        end

        describe "when chaining at_timestamp" do
          subject { WorkPackage.at_timestamp(historic_time).where(id: results.work_packages.pluck(:id)) }

          it "returns the work packages in their historic states" do
            expect(subject.first.description).to eq "This is the original description of the work package"
          end
        end
      end
    end

    describe "when searching only pre-historic work packages (i.e. when the work package does not exist yet)" do
      before { query.timestamps = [pre_historic_time] }

      describe "filter for description containing 'current'" do
        let(:search_term) { 'current' }
        it "does not include the work package matching only in the past" do
          expect(subject).not_to include work_package
        end
      end

      describe "filter for description containing 'original'" do
        let(:search_term) { 'original' }
        it "does not include the work package because it does not exist yet at that time" do
          expect(subject).not_to include work_package
        end
      end
    end

    describe "when filtering for file links" do
      # https://github.com/opf/openproject/pull/11678#issuecomment-1326171087

      let(:storage_1) { create(:storage, creator: user_1) }
      let(:file_link_1) { create(:file_link, creator: user_1, container: work_package, storage: storage_1) }
      let(:project_storage_1) { create(:project_storage, project: project_1, storage: storage_1) }
      before do
        project_storage_1
        file_link_1
      end

      let(:query) do
        login_as(user_1)
        build(:query, user: user_1, project: nil).tap do |query|
          query.filters.clear
          query.add_filter 'file_link_origin_id', '=', [file_link_1.origin_id.to_s]
        end
      end

      it "includes the work package" do
        expect(subject).to include work_package
      end

      it "includes the work package only once" do
        expect(subject.uniq).to eq subject
      end

      describe "when having second reference to the same external file" do
        let(:storage_2) { create(:storage, creator: user_1) }
        let(:file_link_2) { create(:file_link, creator: user_1, container: work_package, storage: storage_2) }
        let(:project_storage_2) { create(:project_storage, project: project_2, storage: storage_2) }
        let(:project_2) { create :project }
        let(:file_link_2) { create(:file_link, creator: user_1, container: work_package, storage: storage_2, origin_id: file_link_1.origin_id) }

        before do
          project_storage_2
          file_link_2
        end

        it "includes the work package" do
          expect(subject).to include work_package
        end

        it "includes the work package only once" do
          expect(subject.uniq).to eq subject
        end
      end
    end

  end
end
