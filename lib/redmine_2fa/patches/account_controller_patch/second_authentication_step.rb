module Redmine2FA
  module Patches
    module AccountControllerPatch
      module SecondAuthenticationStep
        def otp_code_confirm
          if session[:otp_user_id]
            @user = User.find(session[:otp_user_id])

            if @user.authenticate_otp(params[:otp_code], drift: 120)
              reset_otp_session
              successful_authentication(@user)
            else
              increment_failed_attempts
              if session[:otp_failed_attempts] >= 3
                send_otp_code(@user)
                flash[:error] = t('redmine_2fa.notice.auth_code.limit_exceeded_failed_attempts')
              else
                @hide_countdown = true
                flash[:error]   = t('redmine_2fa.notice.auth_code.invalid')
              end
              render 'redmine_2fa'
            end
          else
            redirect_to '/'
          end
        end

        def otp_code_resend
          if session[:otp_user_id]
            @user = User.find(session[:otp_user_id])
            send_otp_code(@user)
            respond_to do |format|
              format.html do
                flash[:notice] = t('redmine_2fa.notice.auth_code.resent_again')
                render 'redmine_2fa'
              end
              format.js
            end
          else
            redirect_to '/'
          end
        end

        private

        def password_authentication
          if !@user.ignore_2fa? && @user.has_otp_auth?
            send_otp_code(@user)
            render 'redmine_2fa'
          else
            super
          end
        end

        def send_otp_code(user)
          Redmine2FA::OtpAuth.new.send_otp_code(user)
          session[:otp_failed_attempts] = 0
        end

        def reset_otp_session
          params[:back_url] = session[:otp_back_url]
          session.delete(:otp_user_id)
          session.delete(:otp_failed_attempts)
          session.delete(:otp_back_url)
        end

        def increment_failed_attempts
          session[:otp_failed_attempts] ||= 0
          session[:otp_failed_attempts] += 1
        end
      end
    end
  end
end
