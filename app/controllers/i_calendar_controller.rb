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
  before_filter :find_user, :find_optional_project, :authorize_access, :check_params, :load_settings
  
  def index
    begin
      # project(s)
      if @user.anonymous?
        if @project
          # the project and its public descendants
          ids = [@project.id] + @project.descendants.find_all { |p|  p.is_public? && p.active? }.collect(&:id)
          project_condition = ["#{Project.table_name}.id IN (?)", ids]
        else
          # all public projects
          project_condition = [Project.visible_by(@user)]
        end
      elsif @user.active?
        if @project
          # the project and its public descendants or where the user is member of
          userproject_ids = @user.memberships.collect(&:project_id).uniq
          ids = [@project.id] + @project.descendants.find_all { |p|  
            p.active? && (p.is_public? || userproject_ids.include?(p.id))
          }.collect(&:id)
          project_condition = ["#{Project.table_name}.id IN (?)", ids]
        else
          # all user-visible and public projects
          project_condition = [Project.visible_by(@user)]
        end
      else
        raise 'User not active.' unless project_condition
      end

      # issue status
      case params[:status].to_sym
      when :open
        issue_status_condition = ["#{IssueStatus.table_name}.is_closed = ?", false]
        version_status_condition = ["#{Version.table_name}.status <> ?", 'closed']
      when :all
        issue_status_condition = []
        version_status_condition = []
      else
        raise "Unknown status: '#{params[:status]}'."
      end

      # assignment
      case params[:assigned_to].to_sym
      when :me
        raise 'Anonymous user cannot have issues assigned.' if @user.anonymous?
        assigned_to_condition = ["assigned_to_id = #{@user.id}"]
      when :'+'
        assigned_to_condition = ["assigned_to_id is not null"]
      when :'*'
        assigned_to_condition = []
      else
        raise "Unknown assigned_to: '#{params[:assigned_to]}.'"
      end

      # query: issues
      c = ARCondition.new()
      c << project_condition
      c << issue_status_condition   unless issue_status_condition.empty?
      c << assigned_to_condition    unless assigned_to_condition.empty?
      issues = Issue.find(
        :all, 
        :include => [:tracker, :assigned_to, :priority, :project, :status, :fixed_version, :author], 
        :conditions => c.conditions
      )
      # query: versions
      c = ARCondition.new()
      c << project_condition
      c << version_status_condition unless version_status_condition.empty?
      versions = Version.find(
        :all,
        :include => [:project], 
        :conditions => c.conditions
      )
    rescue Exception => e
      # we will just deliver an empty ical file instead of showing an error page
      logger.warn('No issues have been selected. ' + e.to_s)
      issues = []
      versions = []
    end

    issue_strategy = @settings['redmics_icsrender_issues'].to_sym
    version_strategy = @settings['redmics_icsrender_versions'].to_sym
    issues_rederer = create_issues_rederer issue_strategy
    versions_rederer = create_versions_rederer version_strategy
    
    events = []
    events += issues.collect(&issues_rederer).flatten
    events += versions.collect(&versions_rederer).flatten
    
    cal = Icalendar::Calendar.new
    events.each { |event| cal.add_event(event)}
    cal.publish
    @cal_string = with_bug_correction(cal.to_ical)
    send_data @cal_string, :type => Mime::ICS, :filename => 'issues.ics'
  end

private

  def create_issues_rederer(type)
    case type
    when :none
      lambda { |issue| 
        []
      }
    when :vevent_full_span
      lambda { |issue| 
        result = create_issue_vevent_full_span(issue)
        apply_issue_common_properties(issue, result)
        apply_issue_event_properties(issue, result)
        result
      }
    when :vevent_end_date
      lambda { |issue| 
        result = create_issue_vevent_end_date(issue)
        apply_issue_common_properties(issue, result)
        apply_issue_event_properties(issue, result)
        result
      }
    when :vevent_start_and_end_date
      lambda { |issue| 
        result = create_issue_vevent_start_and_end_date(issue)
        apply_issue_common_properties(issue, result)
        apply_issue_event_properties(issue, result)
        result
      }
    when :vtodo
      lambda { |issue| 
        result = create_issue_vtodo(issue)
        apply_issue_common_properties(issue, result)
        apply_issue_todo_properties(issue, result)
        result
      }
    end
  end
  
  def create_versions_rederer(type)
    case type
    when :none
      lambda { |version| 
        []
      }
    when :vevent_full_span
      lambda { |version| 
        result = create_version_vevent_full_span(version)
        apply_version_common_properties(version, result)
        apply_version_event_properties(version, result)
        result
      }
    when :vevent_end_date
      lambda { |version| 
        result = create_version_vevent_end_date(version)
        apply_version_common_properties(version, result)
        apply_version_event_properties(version, result)
        result
      }
    when :vevent_start_and_end_date
      lambda { |version| 
        result = create_version_vevent_start_and_end_date(version)
        apply_version_common_properties(version, result)
        apply_version_event_properties(version, result)
        result
      }
    when :vtodo
      lambda { |version| 
        result = create_version_vtodo(version)
        apply_version_common_properties(version, result)
        apply_version_todo_properties(version, result)
        result
      }
    end
  end


  def create_issue_vevent_full_span(issue)
    start_date, due_date = issue_period(issue)
    return [] if start_date.nil? || due_date.nil?
    event = Icalendar::Event.new
    event.dtstart         start_date, {'VALUE' => 'DATE'}
    event.dtend           due_date + 1, {'VALUE' => 'DATE'}
    event.uid             "id:redmics:project:#{issue.project_id}:issue:#{issue.id}@#{Setting.host_name}"
    return [event]
  end
  
  def create_issue_vevent_end_date(issue)
    due_date = issue_period(issue)[1]
    return [] if due_date.nil?
    event = Icalendar::Event.new
    event.dtstart         due_date, {'VALUE' => 'DATE'}
    event.dtend           due_date + 1, {'VALUE' => 'DATE'}
    event.uid             "id:redmics:project:#{issue.project_id}:issue:#{issue.id}@#{Setting.host_name}"
    return [event]
  end
  
  def create_issue_vevent_start_and_end_date(issue)
    start_date, due_date = issue_period(issue)
    if start_date.nil? || due_date.nil?
      return []
    elsif start_date == due_date
      event = Icalendar::Event.new
      event.dtstart       start_date, {'VALUE' => 'DATE'}
      event.dtend         start_date + 1, {'VALUE' => 'DATE'}
      event.summary       "<> #{issue.subject} (#{issue.status.name})"
      event.uid           "id:redmics:project:#{issue.project_id}:issue:#{issue.id}@#{Setting.host_name}"
      return [event]
    end
    result = []
    unless start_date.nil?
      event = Icalendar::Event.new
      event.dtstart       start_date, {'VALUE' => 'DATE'}
      event.dtend         start_date + 1, {'VALUE' => 'DATE'}
      event.summary       "> #{issue.subject} (#{issue.status.name})"
      event.uid           "id:redmics:project:#{issue.project_id}:issue:#{issue.id}:s@#{Setting.host_name}"
      result << event
    end
    unless due_date.nil?
      event = Icalendar::Event.new
      event.dtstart       due_date, {'VALUE' => 'DATE'}
      event.dtend         due_date + 1, {'VALUE' => 'DATE'}
      event.summary       "< #{issue.subject} (#{issue.status.name})"
      event.uid           "id:redmics:project:#{issue.project_id}:issue:#{issue.id}:e@#{Setting.host_name}"
      result << event
    end
    return result
  end
  
  def create_issue_vtodo(issue)
    start_date, due_date = issue_period(issue)
    todo = Icalendar::Todo.new
    unless start_date.nil?
      todo.dtstart        start_date, {'VALUE' => 'DATE'}
    end
    unless due_date.nil?
      todo.due            due_date, {'VALUE' => 'DATE'}
    end
    todo.uid              "id:redmics:project:#{issue.project_id}:issue:#{issue.id}@#{Setting.host_name}"
    return [todo]
  end
  
  def apply_issue_common_properties(issue, result)
    result.each { |event|  
      event.summary       "#{issue.subject} (#{issue.status.name})" unless event.summary
      event.priority      map_priority issue.priority.position
      event.created       issue.created_on.to_date, {'VALUE' => 'DATE'}
      event.last_modified issue.updated_on.to_datetime unless issue.updated_on.nil?
      event.description   issue.description unless issue.description.nil?
      event.add_category  l(:label_issue).upcase
      event.add_contact   issue.assigned_to.name, {"ALTREP" => issue.assigned_to.mail} unless issue.assigned_to.nil?
      event.organizer     "mailto:#{issue.author.mail}", {"CN" => issue.author.name}
      event.url           url_for(:controller => 'issues', :action => 'show', :id => issue.id, :project_id => issue.project_id)
    }
  end
  
  def apply_issue_event_properties(issue, result)
    result.each { |event|  
      event.status        issue.assigned_to ? "CONFIRMED" : "TENTATIVE" unless issue.closed?
    }
  end
  
  def apply_issue_todo_properties(issue, result)
    result.each { |todo|
      if issue.closed?
        todo.status       "COMPLETED"
        todo.completed    issue.updated_on.to_datetime
        todo.percent      100
      elsif issue.assigned_to
        todo.status       "IN-PROCESS"
        todo.percent      issue.done_ratio ? issue.done_ratio.to_i : 0
      else
        todo.status       "NEEDS-ACTION"
      end
    }
  end
  
  def create_version_vevent_full_span(version)
    start_date, due_date = version_period(version)
    return [] if start_date.nil? || due_date.nil?
    event = Icalendar::Event.new
    event.dtstart         start_date, {'VALUE' => 'DATE'}
    event.dtend           due_date + 1, {'VALUE' => 'DATE'}
    event.uid             "id:redmics:project:#{version.project_id}:version:#{version.id}@#{Setting.host_name}"
    return [event]
  end
  
  def create_version_vevent_end_date(version)
    due_date = version_period(version)[1]
    return [] if due_date.nil?
    event = Icalendar::Event.new
    event.dtstart         due_date, {'VALUE' => 'DATE'}
    event.dtend           due_date + 1, {'VALUE' => 'DATE'}
    event.uid             "id:redmics:project:#{version.project_id}:version:#{version.id}@#{Setting.host_name}"
    return [event]
  end
  
  def create_version_vevent_start_and_end_date(version)
    start_date, due_date = version_period(version)
    if start_date.nil? || due_date.nil?
      return []
    elsif start_date == due_date
      event = Icalendar::Event.new
      event.dtstart       start_date, {'VALUE' => 'DATE'}
      event.dtend         start_date + 1, {'VALUE' => 'DATE'}
      event.summary       "<#> #{l(:label_version)} #{version.name}"
      event.uid           "id:redmics:project:#{version.project_id}:version:#{version.id}@#{Setting.host_name}"
      return [event]
    end
    result = []
    unless start_date.nil?
      event = Icalendar::Event.new
      event.dtstart       start_date, {'VALUE' => 'DATE'}
      event.dtend         start_date + 1, {'VALUE' => 'DATE'}
      event.summary       ">> #{l(:label_version)} #{version.name}"
      event.uid           "id:redmics:project:#{version.project_id}:version:#{version.id}:s@#{Setting.host_name}"
      result << event
    end
    unless due_date.nil?
      event = Icalendar::Event.new
      event.dtstart       due_date, {'VALUE' => 'DATE'}
      event.dtend         due_date + 1, {'VALUE' => 'DATE'}
      event.summary       "<< #{l(:label_version)} #{version.name}"
      event.uid           "id:redmics:project:#{version.project_id}:version:#{version.id}:e@#{Setting.host_name}"
      result << event
    end
    return result
  end
  
  def create_version_vtodo(version)
    start_date, due_date = version_period(version)
    todo = Icalendar::Todo.new
    unless start_date.nil?
      todo.dtstart        start_date, {'VALUE' => 'DATE'}
    end
    unless due_date.nil?
      todo.due            due_date, {'VALUE' => 'DATE'}
    end
    todo.uid              "id:redmics:project:#{version.project_id}:version:#{version.id}@#{Setting.host_name}"
    return [todo]
  end
  
  def apply_version_common_properties(version, result)
    result.each { |event|  
      event.summary       "#{l(:label_version)} #{version.name}" unless event.summary
      event.created       version.created_on.to_date, {'VALUE' => 'DATE'}
      event.last_modified version.updated_on.to_datetime unless version.updated_on.nil?
      event.description   version.description unless version.description.nil?
      event.add_category  l(:label_version).upcase
      event.url           url_for(:controller => 'versions', :action => 'show', :id => version.id)
    }
  end

  def apply_version_event_properties(version, result)
    result.each { |event|  
      event.status        "CONFIRMED" unless version.closed?
    }
  end
  
  def apply_version_todo_properties(version, result)
    result.each { |todo|
      if version.closed?
        todo.status       "COMPLETED"
        todo.completed    version.updated_on.to_datetime
        todo.percent      100
      else
        todo.status       "IN-PROCESS"
        todo.percent      version.completed_pourcent.to_i
      end
    }
  end
  
  def issue_period(issue)
    start_date = issue.start_date || (issue.fixed_version.start_date unless issue.fixed_version.nil?)
    due_date = issue.due_date || (issue.fixed_version.due_date unless issue.fixed_version.nil?)
    return [start_date, due_date]
  end

  def version_period(version)
    return [version.start_date, version.due_date]
  end
  
  # isses_priority goes from 1: low, 2: normal to @priority_count: immediate
  # icalendar priority goes from 1: urgent to 9: low (btw. 0: undefined)
  def map_priority(isses_priority)
    case isses_priority
    when 1; 9
    when 2; 5
    when 3..@priority_count; 1
    else 9
    end
  end

  def with_bug_correction(input)
    result = input.gsub(/^SEQ:/, 'SEQUENCE:')
    result = result.gsub(/^PERCENT:/, 'PERCENT-COMPLETE:')
    return result
  end
  
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
    @settings = Setting.plugin_redmine_ics_export
    @priority_count = IssuePriority.all.length
  end
  
end
