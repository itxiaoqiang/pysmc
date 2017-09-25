% THIS IS AN EXAMPLE SCRIPT FOR GENERATING A GRID AND CAN BE USED 
% AS  A TEMPLATE FOR DESIGNING GRIDS

function []=create_grid_smcbase(id,latmin,latmax,lonmin,lonmax,dlat,dlon,ref_grid,boundary,IS_GLOBAL,LAKE_TOL,out_dir,testmode,fname_poly, shift_userpolys)


% 0. Initialization

% 0.a Path to directories 

  bin_dir = '/source/gridgen/noaa/bin';             % matlab scripts location
  ref_dir = '/source/gridgen/noaa/reference_data';  % reference data location
  % out_dir = './out/';                  % output directory

% 0.b Design grid parameters

  % fname_poly = '/source/gridgen/tests/glob05v5/user_polygons.flag'; % A file with switches for using user 
                                     % defined polygons. An example file 
                                     % has been provided with the reference 
                                     % data for an existing user defined 
                                     % polygon database. A switch of 0 
                                     % ignores the polygon while 1 
                                     % accounts for the polygon.

  fname = id;              % file name prefix 
 
  % Grid Definition

  % Gridgen is designed to work with curvilinear and/or rectilinear grids. In
  % both cases it expects a 2D array defining the Longititudes (x values) and 
  % Lattitudes (y values). For curvilinear grids the user will have to use 
  % alternative software to determine these arrays. For rectilinear grids 
  % these are determined by the grid domain and desired resolution as shown 
  % below

  % NOTE : In gridgen we always define the longitudes in the 0 to 365 range as the 
  % boundary polygons have been defined in that range. It is fairly trivial to 
  % rearrange the grids to -180 to 180 range after they have been generated.
 
  dx = str2num(dlon);
  dy = str2num(dlat);
  x1 = str2num(lonmin);
  x2 = str2num(lonmax);
  y1 = str2num(latmin);
  y2 = str2num(latmax);
  LAKE_TOL = str2num(LAKE_TOL);
  IS_GLOBAL = str2num(IS_GLOBAL);
  lon1d = [x1:dx:x2];
  lat1d = [y1:dy:y2];
  [lon,lat] = meshgrid(lon1d,lat1d);

  %ref_grid = 'etopo1';               % reference grid source 
  %                                   %      etopo1 = Etopo1 grid
  %                                   %      etopo2 = Etopo2 grid
  %boundary = 'full';                 % Option to determine which GSHHS 
  %                                   %  .mat file to load
  %                                   %         full = full resolution
  %                                   %         high = 0.2 km
  %                                   %         inter = 1 lm
  %                                   %         low   = 5 km
  %                                   %         coarse = 25 km 

% 0.c Setting the paths for subroutines

  addpath(bin_dir,'-END');

% 0.d Reading Input data

  read_boundary = 1;              % flag to determine if input boundary 
                                  % information needs to be read boundary 
                                  % data files can be significantly large 
                                  % and needs to be read only the first 
                                  % time. So when making multiple grids 
                                  % the flag can be set to 0 for subsequent 
                                  % grids. (Note : If the workspace is
                                  % cleared the boundary data will have to 
                                  % be read again)

  opt_poly = 0;                   % flag for reading the optional user 
                                  % defined polygons. Set to 0 if you do
                                  % not wish to use this opt

  if (~strcmp(fname_poly, '0') & (fname_poly ~= 0))
	  opt_poly = 1;
  end;
  %if (fname_poly ~= 0)
	  %opt_poly = 1;
  %end;

  obstr_scale = 100;
  depth_scale = 1000;

  if (nargin == 14)
      shift_userpolys = 0
  end;

  testmode = str2num(testmode);

  if (testmode == 1)
    fprintf(1,'.........RUNNING IN TEST MODE..................\n');
    fprintf(1,'.........(ignoring coastal polygons)..................\n');
  end;

  if (read_boundary == 1)

      fprintf(1,'.........Reading Boundaries..................\n');


      load([ref_dir,'/coastal_bound_',boundary,'.mat']); 

      N = length(bound);
      Nu = 0;
      if (opt_poly == 1)
          [bound_user,Nu] = optional_bound(ref_dir,fname_poly, shift_userpolys);
      end;
      if (Nu == 0)
          opt_poly = 0;
      end;

  end;

% 0.d Parameter values used in the software

  DRY_VAL = 999999;               % Depth value for dry cells (can change as desired)
  MSL_LEV = 0.0;                  % Bathymetry level indicating wet / dry cells
                                  % all bathymetry values below this level are 
                                  % considered wet
  CUT_OFF = 0.1;                  % Proportion of base bathymetry cells that need to be 
                                  % wet for the target cell to be considered wet. 

  % NOTE : If you have accurate boundary polygons then it is better to have a low value for
  %        CUT_OFF which will make the target bathymetry cell wet even when there are only few
  %        wet cells in the base bathymetry. This will then be cleaned up by the polygons in 
  %        the mask cleanup section. If on the other hand you do not inttend to use the 
  %        polygons to define the coastal domains then you are better off using CUT_OFF = 0.5
 
  LIM_VAL = 0.5;                  % Fraction of cell that has to be inside a polygon for 
                                  % cell to be marked dry;
  OFFSET = max([dx dy]);          % Additional buffer around the boundary to check if cell 
                                  % is crossing boundary. Should be set to largest grid res. 

%  LAKE_TOL = -1;                  % See documentation on remove_lake routine for possible 
                                  % values. 
%  IS_GLOBAL = 0;                  % Set to 1 for global grids

  OBSTR_OFFSET = 1;               % See documentation for create_obstr for details
 
% 1. Generate the grid


  fprintf(1,'.........Creating Bathymetry..................\n');  

  depth = generate_grid(lon,lat,ref_dir,ref_grid,CUT_OFF,MSL_LEV,DRY_VAL);


  if (testmode == 1)
    fprintf(1,'.........Running in test mode, ignoring coastal polygons..................\n');
    m = ones(size(depth)); 
    m(depth == DRY_VAL) = 0; 

	if (opt_poly == 1)
	  lon_start = min(min(lon))-dx;
	  lon_end = max(max(lon))+dx;
	  lat_start = min(min(lat))-dy;
	  lat_end = max(max(lat))+dy;
      coord = [lat_start lon_start lat_end lon_end];
	  [b_opt,N2] = compute_boundary(coord,bound_user);
	  if (N2 ~= 0)
   	      fprintf(1,'...Applying user defined polygons..................\n');
		  m2 = clean_mask(lon,lat,m,b_opt,LIM_VAL,OFFSET);      
	  else
		  m2 = m;
	  end;
	end;

	fprintf(1,'.........Separating Water Bodies..................\n');

	fprintf(1,'Lake_tol being passed to remove_lake: %d\n', LAKE_TOL);
	[m4,mask_map] = remove_lake(m2,LAKE_TOL,IS_GLOBAL);
	sx1 = zeros(size(depth)); 
	sy1 = zeros(size(depth)); 
  	write_ww3file([out_dir,'/',fname,'.mask_map_before_user'],m);
  	write_ww3file([out_dir,'/',fname,'.mask_map'],m2);
  	write_ww3file([out_dir,'/',fname,'.before_remove_lakes'],m);
  	write_ww3file([out_dir,'/',fname,'.after_remove_lakes'],m4);
  else

% 2. Computing boundaries within the domain

  fprintf(1,'.........Computing Boundaries..................\n');

% 2.a Set the domain big enough to include the cells along the edges of the grid
  
  lon_start = min(min(lon))-dx;
  lon_end = max(max(lon))+dx;
  lat_start = min(min(lat))-dy;
  lat_end = max(max(lat))+dy;

% 2.b Extract the boundaries from the GSHHS and the optional databases
%     the subset of polygons within the grid domain are stored in b and b_opt
%     for GSHHS and user defined polygons respectively

  coord = [lat_start lon_start lat_end lon_end];
  [b,N1] = compute_boundary(coord,bound);
  if (opt_poly == 1)
   	  fprintf(1,'...Applying user defined polygons..................\n');
      [b_opt,N2] = compute_boundary(coord,bound_user);
  end;

% 3. Set up Land - Sea Mask

% 3.a Set up initial land sea mask. The cells can either all be set to wet
%      or to make the code more efficient the cells marked as dry in 
%      'generate_grid' can be marked as dry cells

  m = ones(size(depth)); 
  m(depth == DRY_VAL) = 0; 

% 3.b Split the larger GSHHS polygons for efficient computation of the 
%     land sea mask. This is an optional step but recomended as it  
%     significantly speeds up the computational time. Rule of thumb is to
%     set the limit for splitting the polygons at least 4-5 times dx,dy

  fprintf(1,'.........Splitting Boundaries..................\n');

  if isstruct(b)
  	b_split = split_boundary(b,5*max([dx dy]));

% 3.c Get a better estimate of the land sea mask using the polygon data sets.
%     (NOTE : This part will have to be commented out if cells above the 
%      MSL are being marked as wet, like in inundation studies)

  fprintf(1,'.........Cleaning Mask..................\n');
  
 % GSHHS Polygons. If 'split_boundary' routine is not used then replace
 % b_split with b  


  m2 = clean_mask(lon,lat,m,b_split,LIM_VAL,OFFSET);
 
 % Masking out regions defined by optional polygons

  if (opt_poly == 1 && N2 ~= 0)
      m3 = clean_mask(lon,lat,m2,b_opt,LIM_VAL,OFFSET);       
  else                                              
      m3 = m2;
  end;

% 3.d Remove lakes and other minor water bodies

  fprintf(1,'.........Separating Water Bodies..................\n');

  [m4,mask_map] = remove_lake(m3,LAKE_TOL,IS_GLOBAL); 
  
% 4. Generate sub - grid obstruction sets in x and y direction, based on 
%    the final land/sea mask and the coastal boundaries
    
  fprintf(1,'.........Creating Obstructions..................\n');

  [sx1,sy1] = create_obstr(lon,lat,b,m4,OBSTR_OFFSET,OBSTR_OFFSET);      
  
% 5. Output to ascii files for WAVEWATCH III

  else
  	  fprintf(1,'.......No boundaries in domain..............\n');
	  m4 = m;
	  sx1 = zeros(size(depth)); 
	  sy1 = zeros(size(depth)); 
  end;

  end; % testmode check

  d = round((depth)*depth_scale);
  d1 = round((sx1)*obstr_scale);
  d2 = round((sy1)*obstr_scale);
  dlon=dx; dlat=dy;
  save([out_dir,'/',fname '.mat'], 'dlon', 'dlat', 'lon', 'lat', 'depth', 'm3', 'm4',...
        'mask_map', 'sx1', 'sy1'); 

% 6. Vizualization (this part can be commented out if resources are limited)

  %figure(1);
  %clf;
  %loc = find(m4 == 0);
  %d2 = depth;
  %d2(loc) = NaN;

  %pcolor(lon,lat,d2);
  %shading interp;
  %colorbar;
  %title(['Bathymetry for ',fname],'fontsize',14);
  %set(gca,'fontsize',14);
  %clear d2;

  %figure(2);
  %clf;
  %d2 = mask_map;
  %loc2 = find(mask_map == -1);
  %d2(loc2) = NaN;

  %pcolor(lon,lat,d2);
  %shading flat;
  %colorbar;
  %title(['Different water bodies for ',fname],'fontsize',14);
  %set(gca,'fontsize',14);
  %clear d2;
  % 
  %figure(3);
  %clf;

  %pcolor(lon,lat,m4);
  %shading flat;
  %colorbar;
  %title(['Final Land-Sea Mask ',fname],'fontsize',14);
  %set(gca,'fontsize',14);

  %figure(4);
  %clf;
  %d2 = sx1;
  %d2(loc) = NaN;

  %pcolor(lon,lat,d2);
  %shading flat;
  %colorbar;
  %title(['Sx obstruction for ',fname],'fontsize',14);
  %set(gca,'fontsize',14);
  %clear d2;

  %figure(5);
  %clf;
  %d2 = sy1;
  %d2(loc) = NaN;

  %pcolor(lon,lat,d2);
  %shading flat;
  %colorbar;
  %title(['Sy obstruction for ',fname],'fontsize',14);
  %set(gca,'fontsize',14);
  %clear d2;
  exit

end
% END OF SCRIPT
