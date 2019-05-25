.SUFFIXES: .f .F .F90 .f90 .o .mod
.SHELL: /bin/sh

## COMPILER CONFIGURATION ##

FC = gfortran

INC_NC  = -I/opt/local/include
LIB_NC  = -L/opt/local/lib -lnetcdff -lnetcdf

LISROOT = /Users/robinson/apps/lis/lis
INC_LIS = -I${LISROOT}/include 
LIB_LIS = -L${LISROOT}/lib -llis

YELMOROOT = /Users/robinson/models/EURICE/yelmox/yelmo
INC_YELMO = -I${YELMOROOT}/libyelmo/include 
LIB_YELMO = -L${YELMOROOT}/libyelmo/include -lyelmo

FFLAGS  = -ffree-line-length-none 
LFLAGS  = $(LIB_NC) $(LIB_LIS) $(LIB_YELMO)

DFLAGS = -O2

## PROGRAM COMPILATION ##

# Compile the static library libyelmo,
# using Makefile located in $(YELMOROOT) directory 
yelmo-static: 
		$(MAKE) -C $(YELMOROOT) yelmo-static 

yelmot : yelmo-static 
		$(FC) $(DFLAGS) $(FFLAGS) $(INC_LIS) $(INC_YELMO) -o yelmot.x yelmo_template.f90 \
			$(LFLAGS) 
		@echo " "
		@echo "    yelmot.x (compiled from yelmo_template.f90) is ready."
		@echo " "

.PHONY : usage
usage:
	@echo ""
	@echo "    * USAGE * "
	@echo ""
	@echo " make yelmot     : compiles yelmot.x, template program for coupling Yelmo in a Fortran program."
	@echo " make clean      : cleans object files"
	@echo ""

clean:
	rm -f *.x
