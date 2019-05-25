

program yelmo_test

    use ncio 
    use yelmo 
    
    implicit none 

    type(yelmo_class)      :: yelmo1

    character(len=512) :: path_par, path_const  
    real(prec) :: time_init, time_end, time, dtt, dt1D_out, dt2D_out   
    character(len=256) :: outfldr, file1D, file2D
    integer    :: n

    ! Determine the parameter file from the command line 
    call yelmo_load_command_line_args(path_par)

    ! Timing and other parameters 
    call nml_read(path_par,"control","time_init",    time_init)                 ! [yr] Starting time
    call nml_read(path_par,"control","time_end",     time_end)                  ! [yr] Ending time
    call nml_read(path_par,"control","dtt",          dtt)                       ! [yr] Main loop time step 
    call nml_read(path_par,"control","dt1D_out",     dt1D_out)                  ! [yr] Frequency of 1D output 
    call nml_read(path_par,"control","dt2D_out",     dt2D_out)                  ! [yr] Frequency of 2D output 

    ! Assume program is running from the output folder
    outfldr = "./"

    ! Define input and output locations 
    path_const = trim(outfldr)//"yelmo_const_Earth.nml"
    file1D     = trim(outfldr)//"yelmo1D.nc"
    file2D     = trim(outfldr)//"yelmo2D.nc"

    ! === Initialize ice sheet model =====

    ! General initialization of yelmo constants (used globally)
    call yelmo_global_init(path_const)

    ! Initialize data objects and load initial topography
    call yelmo_init(yelmo1,filename=path_par,grid_def="file",time=time_init)

    ! === Set initial boundary conditions for current time and yelmo state =====
    ! ybound: z_bed, z_sl, H_sed, H_w, smb, T_srf, bmb_shlf , Q_geo

    yelmo1%bnd%z_sl     = 0.0           ! [m]
    yelmo1%bnd%H_sed    = 0.0           ! [m]
    yelmo1%bnd%H_w      = 0.0           ! [m]
    yelmo1%bnd%Q_geo    = 50.0          ! [mW/m2]
    
    yelmo1%bnd%bmb_shlf = -20.0         ! [m.i.e./a]
    yelmo1%bnd%T_shlf   = T0            ! [K]   

    ! Impose present-day surface mass balance and present-day temperature field
    yelmo1%bnd%smb      = yelmo1%dta%pd%smb        ! [m.i.e./a]
    yelmo1%bnd%T_srf    = yelmo1%dta%pd%T_srf      ! [K]
    
    call yelmo_print_bound(yelmo1%bnd)

    ! Initialize state variables (dyn,therm,mat)
    ! (initialize temps with robin method with a cold base)
    call yelmo_init_state(yelmo1,path_par,time=time_init,thrm_method="robin-cold")

    ! Initialize 2D file 
    call yelmo_write_init(yelmo1,file2D,time_init=time_init,units="years")  
    call write_step_2D(yelmo1,file2D,time=time_init)
    
    ! Initialize 1D file 
    call write_yreg_init(yelmo1,file1D,time_init=time_init,units="years",mask=yelmo1%bnd%ice_allowed)
    call write_yreg_step(yelmo1%reg,file1D,time=time_init) 
    

    ! Advance timesteps
    do n = 1, ceiling((time_end-time_init)/dtt)

        ! Get current time 
        time = time_init + n*dtt

        ! Update ice sheet 
        call yelmo_update(yelmo1,time)

        ! == MODEL OUTPUT =======================================================

        ! Write 2D output
        if (mod(nint(time*100),nint(dt2D_out*100))==0) then
            call write_step_2D(yelmo1,file2D,time=time)
        end if 

        ! Write 1D output 
        if (mod(nint(time*100),nint(dt1D_out*100))==0) then 
            call write_yreg_step(yelmo1%reg,file1D,time=time) 
        end if 

        if (mod(time,10.0)==0) then
            write(*,"(a,f14.4)") "yelmo::       time = ", time
        end if 

    end do 
    ! == Finished time loop == 

    ! Finalize program
    call yelmo_end(yelmo1,time=time)

contains

    subroutine write_step_2D(ylmo,filename,time)

        implicit none 
        
        type(yelmo_class), intent(IN) :: ylmo
        character(len=*),  intent(IN) :: filename
        real(prec), intent(IN) :: time

        ! Local variables
        integer    :: ncid, n
        real(prec) :: time_prev 

        ! Open the file for writing
        call nc_open(filename,ncid,writable=.TRUE.)

        ! Determine current writing time step 
        n = nc_size(filename,"time",ncid)
        call nc_read(filename,"time",time_prev,start=[n],count=[1],ncid=ncid) 
        if (abs(time-time_prev).gt.1e-5) n = n+1 

        ! Update the time step
        call nc_write(filename,"time",time,dim1="time",start=[n],count=[1],ncid=ncid)

        ! Basic ice-sheet variables
        call nc_write(filename,"H_ice",ylmo%tpo%now%H_ice,units="m",long_name="Ice thickness", &
                      dim1="xc",dim2="yc",dim3="time",start=[1,1,n],ncid=ncid)
        call nc_write(filename,"z_srf",ylmo%tpo%now%z_srf,units="m",long_name="Surface elevation", &
                      dim1="xc",dim2="yc",dim3="time",start=[1,1,n],ncid=ncid)
        call nc_write(filename,"z_bed",ylmo%bnd%z_bed,units="m",long_name="Bedrock elevation", &
                      dim1="xc",dim2="yc",dim3="time",start=[1,1,n],ncid=ncid) 
        call nc_write(filename,"uxy_s",ylmo%dyn%now%uxy_s,units="m/a",long_name="Surface velocity (magnitude)", &
                       dim1="xc",dim2="yc",dim3="time",start=[1,1,n],ncid=ncid)

        call nc_write(filename,"mask_bed",ylmo%tpo%now%mask_bed,units="",long_name="Bed mask", &
                      dim1="xc",dim2="yc",dim3="time",start=[1,1,n],ncid=ncid)
        
        ! Close the netcdf file
        call nc_close(ncid)

        return 

    end subroutine write_step_2D

end program yelmo_test 



