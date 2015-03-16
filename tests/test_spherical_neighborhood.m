function test_suite = test_spherical_neighborhood
    initTestSuite;


function test_simple_neighborhood
    ds=cosmo_synthetic_dataset();
    nh1=cosmo_spherical_neighborhood(ds,'radius',0,'progress',false);
    assertEqual(nh1.a,ds.a);
    assertEqual(nh1.fa.i,ds.fa.i);
    assertEqual(nh1.fa.j,ds.fa.j);
    assertEqual(nh1.fa.k,ds.fa.k);
    assertEqual(nh1.fa.nvoxels,ones(1,6));
    assertEqual(nh1.fa.radius,zeros(1,6));
    assertEqual(nh1.fa.center_ids,1:6);
    assertEqual(nh1.neighbors,num2cell((1:6)'));




    nh2=cosmo_spherical_neighborhood(ds,'radius',1.5,'progress',false);
    assertEqual(nh2.a,ds.a);
    assertEqual(nh2.fa.i,ds.fa.i);
    assertEqual(nh2.fa.j,ds.fa.j);
    assertEqual(nh2.fa.k,ds.fa.k);
    assertEqual(nh2.fa.nvoxels,[4 6 4 4 6 4]);
    assertEqual(nh2.fa.radius,ones(1,6)*1.5);
    assertEqual(nh2.fa.center_ids,1:6);
    assertEqual(nh2.neighbors,{ [ 1 4 2 5 ];...
                                 [ 2 1 5 3 4 6 ];...
                                 [ 3 2 6 5 ];...
                                 [ 4 1 5 2 ];...
                                 [ 5 4 2 6 1 3 ];...
                                 [ 6 5 3 2 ] });

    nh3=cosmo_spherical_neighborhood(ds,'count',4,'progress',false);
    assertEqual(nh3.a,ds.a);
    assertEqual(nh3.fa.i,ds.fa.i);
    assertEqual(nh3.fa.j,ds.fa.j);
    assertEqual(nh3.fa.k,ds.fa.k);
    assertEqual(nh3.fa.nvoxels,[4 4 4 4 4 4]);
    assertElementsAlmostEqual(nh3.fa.radius,...
                                [sqrt(2) 1 sqrt(2) sqrt(2) 1 sqrt(2)],...
                                'relative',1e-3);
    assertEqual(nh3.fa.center_ids,1:6);
    assertEqual(nh3.neighbors,{ [ 1 4 2 5 ];...
                                 [ 2 1 5 3 ];...
                                 [ 3 2 6 5 ];...
                                 [ 4 1 5 2 ];...
                                 [ 5 4 2 6 ];...
                                 [ 6 5 3 2 ] });

function test_exceptions
    ds=cosmo_synthetic_dataset();
    aet=@(x)assertExceptionThrown(@()...
                cosmo_spherical_neighborhood(x{:}),'');
    aet({ds});
    aet({ds,'foo'});
    aet({ds,'foo',1});
    aet({ds,'radius',[1 2]});
    aet({ds,'count',[1 2]});
    aet({ds,'radius',-1});
    aet({ds,'count',-1});
    aet({ds,'radius',1,'count',1});
    aet({ds,'count',7});
    aet({'foo','count',7});

function test_sparse_dataset
    nfeatures_test=3;

    ds=cosmo_synthetic_dataset('size','big');
    nf=size(ds.samples,2);
    rp=randperm(nf);
    ids=repmat(rp(1:round(nf*.4)),1,2);
    ds=cosmo_slice(ds,ids,2);


    nh4=cosmo_spherical_neighborhood(ds,'radius',3.05,'progress',false);
    assertEqual(nh4.a,ds.a);
    assertEqual(nh4.fa.i,ds.fa.i);
    assertEqual(nh4.fa.j,ds.fa.j);
    assertEqual(nh4.fa.k,ds.fa.k);

    rp=randperm(size(ds.samples,2));
    center_ids=rp(1:nfeatures_test);

    ijk=[ds.fa.i; ds.fa.j; ds.fa.k];
    for center_id=center_ids
        ijk_center=ijk(:,center_id);
        delta=sum(bsxfun(@minus,ijk_center,ijk).^2,1).^.5;
        nbr_ids=find(delta<=3.05);
        assertEqual(nbr_ids,sort(nh4.neighbors{center_id}));
    end


function test_with_freq_dimension_dataset
    ds=cosmo_synthetic_dataset('size','big');
    nfeatures=size(ds.samples,2);

    freqs=[2 4 6];
    nfreqs=numel(freqs);
    ds_cell=cell(nfreqs,1);
    for k=1:nfreqs
        ds_freq=ds;
        ds_freq.a.fdim.labels=[{'freq'};ds_freq.a.fdim.labels];
        ds_freq.a.fdim.values=[{freqs};ds_freq.a.fdim.values];
        ds_freq.fa.freq=ones(1,nfeatures)*k;
        ds_cell{k}=ds_freq;
    end

    ds=cosmo_stack(ds_cell,2);
    rp=randperm(nfeatures*nfreqs);
    ds=cosmo_slice(ds,rp(1:nfeatures),2);

    radius=5+rand()*3;
    nh=cosmo_spherical_neighborhood(ds,'radius',radius,'progress',false);

    assertEqual(nh.fa.i,ds.fa.i);
    assertEqual(nh.fa.j,ds.fa.j);
    assertEqual(nh.fa.k,ds.fa.k);
    assertEqual(nh.a.fdim.labels,ds.a.fdim.labels(2:4));
    assertEqual(nh.a.fdim.values,ds.a.fdim.values(2:4));

    ijk=[ds.fa.i; ds.fa.j; ds.fa.k];

    rp=randperm(nfeatures);
    rp=rp(1:10);
    for r=rp
        nbrs=nh.neighbors{r};

        ijk_center=ijk(:,r);
        delta=sum(bsxfun(@minus,ijk_center,ijk).^2,1).^.5;
        assertEqual(find(delta<=radius), sort(nbrs));
    end

    ds2=ds;
    ds2.a.fdim.values=cellfun(@transpose,ds2.a.fdim.values,...
                            'UniformOutput',false);
    nh2=cosmo_spherical_neighborhood(ds,'radius',radius,'progress',false);
    assertEqual(nh,nh2);
    assertFalse(isfield(nh.fa,'inside'));

function test_meeg_source_dataset
    ds=cosmo_synthetic_dataset('type','source','size','normal');
    nf=size(ds.samples,2);

    [unused,idxs]=sort(cosmo_rand(1,nf*4,'seed',1));
    rps=mod(idxs-1,nf)+1;
    rp=rps(round(nf/2)+(1:(3*nf)));

    ds=cosmo_slice(ds,rp,2);

    radius=1.2+.2*rand();

    voxel_size=10;
    nh=cosmo_spherical_neighborhood(ds,'radius',radius,'progress',false);

    assertEqual(nh.fa.pos,ds.fa.pos);
    assertEqual(nh.a,ds.a);

    count=ceil(4/3*pi*(radius)^3 * .5);
    nh2=cosmo_spherical_neighborhood(ds,'count',count,'progress',false);
    assertEqual(nh2.fa.pos,ds.fa.pos);
    assertEqual(nh2.a,ds.a);

    rp=rp(1:10);

    pos=nh.a.fdim.values{1}(:,ds.fa.pos);
    inside=ds.fa.inside;

    for r=rp
        if inside(r)
            d=sum(bsxfun(@minus,pos(:,r),pos).^2,1).^.5;
            idxs=find(d<=(radius*voxel_size) & inside);
        else
            idxs=zeros(1,0);
        end

        assertEqual(sort(nh.neighbors{r}),sort(idxs));
    end
    assertEqual(inside,nh.fa.inside);

    [p,q]=cosmo_overlap(nh.neighbors,nh2.neighbors);

    dp=diag(p);
    dq=diag(q);

    assertEqual(isnan(dp),~inside');
    assertEqual(isnan(dq),~inside');

    assertTrue(mean(dp(inside))>.1);
    assertTrue(mean(dq(inside))>.4);

function test_fmri_fixed_number_of_features()
    ds=cosmo_synthetic_dataset('size','normal');
    nf=size(ds.samples,2);
    [unused,idxs]=sort(cosmo_rand(1,nf*3,'seed',1));
    rps=mod(idxs-1,nf)+1;
    rp=rps(round(nf/2)+(1:(2*nf)));
    ds=cosmo_slice(ds,rp,2);


    count=20;
    nh=cosmo_spherical_neighborhood(ds,'count',count,'progress',false);
    rp=randperm(nf);
    rp=rp(1:10);

    pos=[ds.fa.i;ds.fa.j;ds.fa.k];
    for r=rp
        d=sum(bsxfun(@minus,pos(:,r),pos).^2,1).^.5;
        idxs=nh.neighbors{r};
        d_inside=d(idxs);
        d_outside=d(setdiff(1:nf,idxs));
        assert(max(d_inside)<=min(d_outside));
        assertElementsAlmostEqual(max(d_inside),nh.fa.radius(r),...
                                                'absolute',1e-4);
    end




