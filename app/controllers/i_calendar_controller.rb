# redmics - redmine ics export plugin
# Copyright (c) 2010  Frank Schwarz, frank.schwarz@buschmais.com
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

require 'icalendar'

class ICalendarController < ApplicationController
  unloadable
  
  accept_key_auth :index
  before_filter :find_user, :find_optional_project, 
                :authorize_access, :check_params, 
                :load_settings
  
  def index
    export = Redmics::Export.new(self)
    export.settings(:user => @user, 
                    :project => @project,
                    :status => params[:status].to_sym,
                    :assigned_to => params[:assigned_to].to_sym,
                    :issue_strategy => @settings[:redmics_icsrender_issues].to_sym,
                    :version_strategy => @settings[:redmics_icsrender_versions].to_sym
                    )
    cal = export.icalendar
    cal.publish
    send_data cal.to_ical, :type => Mime::ICS, :filename => 'issues.ics'
  end

private

  def find_user
    @user = User.current
  rescue ActiveRecord::RecordNotFound
    render_403
  end

  def find_optional_project
    return true unless params[:project_id]
    @project = Project.find_by_identifier(params[:project_id]);
  rescue ActiveRecord::RecordNotFound
    render_404
  end
  
  def authorize_access
    # we have a key but no autenticated user
    render_404 if params[:key] && @user.anonymous?
    # we have a project-id but no project
    render_404 if params[:project_id] && @project.nil? 
    # we have a project but calendar viewing is forbidden for the (possibly anonymous) user
    render_403 if @project && ! @user.allowed_to?(:view_calendar, @project)
    # we do not have a project and calendar viewing is globally forbidden for the autenticated user
    render_403 if @project.nil? && ! @user.allowed_to?(:view_calendar, nil, :global => true)
  end
  
  def check_params
    # we answer with 'not found' if parameters seem to be bogus
    render_404 unless params[:status]
    render_404 unless params[:assigned_to]
    render_404 if params[:status].length > 10
    render_404 if params[:assigned_to].length > 10
  end
  
  def load_settings
    global_prefs = Setting.plugin_redmine_ics_export
    @settings = { }
    [:redmics_icsrender_issues, :redmics_icsrender_versions].each { |item|  
      @settings[item] = @user.pref[item] || global_prefs[item]
    }
  end
  
end
