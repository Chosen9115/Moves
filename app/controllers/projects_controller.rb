class ProjectsController < ApplicationController
  def create
    @project = Project.new(project_params)

    if @project.save
      session[:project_id] = @project.id
      redirect_to request.referer || root_path, notice: "Project created."
    else
      redirect_to request.referer || root_path, alert: "Could not create project: #{@project.errors.full_messages.join(', ')}"
    end
  end

  def update
    @project = Project.find(params[:id])
    if @project.update(project_params)
      if request.xhr? || request.content_type&.include?("json")
        head :ok
      else
        redirect_to request.referer || root_path, notice: "Project updated."
      end
    else
      if request.xhr? || request.content_type&.include?("json")
        head :unprocessable_entity
      else
        redirect_to request.referer || root_path, alert: "Could not update project."
      end
    end
  end

  def destroy
    @project = Project.find(params[:id])
    @project.destroy
    session.delete(:project_id) if session[:project_id] == @project.id
    if request.xhr? || request.content_type&.include?("json")
      head :ok
    else
      redirect_to root_path, notice: "Project deleted."
    end
  end

  private

  def project_params
    params.require(:project).permit(:name, :color, :cadence)
  end
end
