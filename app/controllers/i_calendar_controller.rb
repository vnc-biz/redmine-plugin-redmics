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
  
  def index
    begin
      user = User.current
      project = Project.find_by_identifier(params[:project_id]);
      raise "Unknown project: #{params[:project_id]}." if params[:project_id] && project.nil? 
      
      # project
      if user.anonymous?
        if project && user.allowed_to?(:view_calendar, project)
          # the project and its public descendents
          ids = [project.id] + project.descendants.find_all { |p|  p.is_public? && p.active? }.collect(&:id)
          project_condition = ["#{Project.table_name}.id IN (?)", ids]
        elsif project.nil? && user.allowed_to?(:view_calendar, nil, :global => true)
          # all public projects
          project_condition = [Project.visible_by(user)]
        end
      elsif user.active?
        if project && user.allowed_to?(:view_calendar, project)
          # the project and its public descendents or where the user is member of
          userproject_ids = user.memberships.collect(&:project_id).uniq
          ids = [project.id] + project.descendants.find_all { |p|  
            p.active? && (p.is_public? || userproject_ids.include?(p.id))
          }.collect(&:id)
          project_condition = ["#{Project.table_name}.id IN (?)", ids]
        elsif project.nil?
          # all user-visible and public projects
          project_condition = [Project.visible_by(user)]
        end
      end
      raise 'Not allowed.' unless project_condition

      # issue status
      case params[:status]
      when 'open'
        issue_status_condition = ["#{IssueStatus.table_name}.is_closed = ?", false]
        version_status_condition = ["#{Version.table_name}.status <> ?", 'closed']
      when 'all'
        issue_status_condition = []
        version_status_condition = []
      else
        raise "Unknown status: '#{params[:status]}'."
      end

      # assignment
      case params[:assigned_to]
      when 'me'
        raise 'Anonymous user cannot have issues assigned.' if user.anonymous?
        assigned_to_condition = ["assigned_to_id = #{user.id}"]
      when '+'
        assigned_to_condition = ["assigned_to_id is not null"]
      when '*'
        assigned_to_condition = []
      else
        raise "Unknown assigned_to: '#{params[:assigned_to]}.'"
      end

      events = []
      # queriy: issues
      c = ARCondition.new()
      c << project_condition
      c << issue_status_condition   unless issue_status_condition.empty?
      c << assigned_to_condition    unless assigned_to_condition.empty?
      events += Issue.find(
        :all, 
        :include => [:tracker, :assigned_to, :priority, :project, :status, :fixed_version, :author], 
        :conditions => c.conditions
      )
      # queriy: versions
      c = ARCondition.new()
      c << project_condition
      c << version_status_condition unless version_status_condition.empty?
      events += Version.find(
        :all,
        :include => [:project], 
        :conditions => c.conditions
      )
    rescue Exception => e
      # we will just deliver an empty ical file instead of showing an error page
      logger.warn('No issues have been selected. ' + e)
      events = []
    end
    @cal_string = create_calendar(events).to_ical
    send_data @cal_string, :type => Mime::ICS, :filename => 'issues.ics'
  end

private
  
  def create_calendar(events)
    cal = Icalendar::Calendar.new
    events.each { |i|
      # issue due date or associated version due date, skip if neither date is present
      due_date = i.due_date
      due_date ||= i.fixed_version.due_date if (i.is_a? Issue) && (i.fixed_version != nil)
      next if due_date.nil?
      
      event = Icalendar::Event.new
      
      event.dtstart        due_date, {'VALUE' => 'DATE'}
      event.dtend          due_date + 1, {'VALUE' => 'DATE'}
      event.created        i.created_on.to_date, {'VALUE' => 'DATE'}
      event.last_modified  i.updated_on.to_datetime unless i.updated_on.nil?
      event.description    i.description unless i.description.nil?
      
      if i.is_a? Issue
        event.summary      "#{i.subject} (#{i.status.name})"
        event.categories   [i.fixed_version.name] unless i.fixed_version.nil?
        event.add_contact  i.assigned_to.name, {"ALTREP" => i.assigned_to.mail} unless i.assigned_to.nil?
        event.organizer    "mailto:#{i.author.mail}", {"CN" => i.author.name}
        event.status       i.assigned_to == nil ? "TENTATIVE" : "CONFIRMED"
        event.url          url_for(:controller => 'issues', :action => 'show', :id => i.id, :project_id => i.project_id)
        event.uid          "id:redmics:project:#{i.project_id}:issue:#{i.id}@#{Setting.host_name}"
      elsif i.is_a? Version
        event.summary      "%s '#{i.name}'" % l(:label_calendar_deadline)
        event.url          url_for(:controller => 'versions', :action => 'show', :id => i.id)
        event.uid          "id:redmics:project:#{i.project_id}:version:#{i.id}@#{Setting.host_name}"
      else
      end
      cal.add_event(event)
    }
    return cal
  end

end
