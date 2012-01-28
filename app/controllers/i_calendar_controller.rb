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
                :decode_url_rendering_settings,
                :authorize_access, :check_params, 
                :load_settings
  
  def index
    export = Redmics::Export.new(self)
    export.settings(:user => @user, 
                    :project => @project,
                    :status => params[:status].to_sym,
                    :assigned_to => params[:assigned_to].to_sym,
                    :issue_strategy => @settings[:redmics_icsrender_issues].to_sym,
                    :version_strategy => @settings[:redmics_icsrender_versions].to_sym,
                    :summary_strategy => @settings[:redmics_icsrender_summary].to_sym,
                    :description_strategy => @settings[:redmics_icsrender_description].to_sym
                    )
    cal = export.icalendar
    cal.publish
    send_data cal.to_ical, :type => 'text/calendar; charset=utf-8', :filename => 'issues.ics'
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
  
  def decode_url_rendering_settings
    options = [:none, :vevent_full_span, :vevent_end_date, :vevent_start_and_end_date, :vtodo]
    options_summary = [:plain, :status, :ticket_number_and_status]
    options_description = [:plain, :url_and_version, :full]
    @rendering = {}
    if params[:render_issues] =~ /[0-3]/
      @rendering[:redmics_icsrender_issues] = options[params[:render_issues].to_i]
    end
    if params[:render_versions] =~ /[0-3]/
      @rendering[:redmics_icsrender_versions] = options[params[:render_versions].to_i]
    end
    if params[:render_summary] =~ /[0-2]/
      @rendering[:redmics_icsrender_summary] = options_summary[params[:render_summary].to_i]
    end
    if params[:render_description] =~ /[0-2]/
      @rendering[:redmics_icsrender_description] = options_description[params[:render_description].to_i]
    end
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
    defaults = Redmine::Plugin.find(:redmine_ics_export).settings[:default]
    global_prefs = Setting.plugin_redmine_ics_export
    @settings = { }
    defaults.keys.each { |item|
      @settings[item] = @rendering[item] ||
        @user.pref[item] ||
        global_prefs[item] ||
        defaults[item]
    }
  end
end
