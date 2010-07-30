create table das__das__main (
		unique_key integer,
		chrid varchar(10),
		chrstart integer,
		chrend integer,
		dastype varchar(20),
		dasmethod varchar(20),
		dasori varchar(1)
	);
insert into das__das__main values (1,'1','1000','2000','exon','manual','+');
insert into das__das__main values (2,'X','80','4500','exon','manual','+');
insert into das__das__main values (2,'8','700','9000','exon','manual','+');

create schema api_test;
set search_path='api_test';
create table a__mn__main (
		main_id_key integer,
		plain varchar(10),
		with_dim1_bool integer default 0,
		with_dim2_bool integer default 0
	);
insert into a__mn__main values (11, 'pval1', 0, 0);
insert into a__mn__main values (12, 'afval1', 0, 0);
insert into a__mn__main values (13, 'mvala1', 0, 0);
insert into a__mn__main values (14, 'mvalb1', 0, 0);
insert into a__mn__main values (15, 'localph1', 0, 0);
insert into a__mn__main values (16, 'remoteph1', 0, 0);
insert into a__mn__main values (21, 'pval1', 1, 0);
insert into a__mn__main values (22, 'afval1', 1, 0);
insert into a__mn__main values (23, 'mvala1', 1, 0);
insert into a__mn__main values (24, 'mvalb1', 1, 0);
insert into a__mn__main values (25, 'localph1', 1, 0);
insert into a__mn__main values (26, 'remoteph1', 1, 0);
insert into a__mn__main values (31, 'pval1', 0, 1);
insert into a__mn__main values (32, 'afval1', 0, 1);
insert into a__mn__main values (33, 'mvala1', 0, 1);
insert into a__mn__main values (34, 'mvalb1', 0, 1);
insert into a__mn__main values (35, 'localph1', 0, 1);
insert into a__mn__main values (36, 'remoteph1', 0, 1);
insert into a__mn__main values (41, 'pval1', 1, 1);
insert into a__mn__main values (42, 'afval1', 1, 1);
insert into a__mn__main values (43, 'mvala1', 1, 1);
insert into a__mn__main values (44, 'mvalb1', 1, 1);
insert into a__mn__main values (45, 'localph1', 1, 1);
insert into a__mn__main values (46, 'remoteph1', 1, 1);
alter table a__mn__main add plaina varchar(10);
update a__mn__main set plaina=plain;
alter table a__mn__main add plainafilt varchar(10);
update a__mn__main set plainafilt=plain;
create table b__mn__main (
		main_id_key integer,
		plain varchar(10),
		with_dim1_bool integer default 0,
		with_dim2_bool integer default 0 
	);
insert into b__mn__main values (11, 'pval1', 0, 0);
insert into b__mn__main values (12, 'afval1', 0, 0);
insert into b__mn__main values (13, 'mvala1', 0, 0);
insert into b__mn__main values (14, 'mvalb1', 0, 0);
insert into b__mn__main values (15, 'localph1', 0, 0);
insert into b__mn__main values (16, 'remoteph1', 0, 0);
insert into b__mn__main values (21, 'pval1', 1, 0);
insert into b__mn__main values (22, 'afval1', 1, 0);
insert into b__mn__main values (23, 'mvala1', 1, 0);
insert into b__mn__main values (24, 'mvalb1', 1, 0);
insert into b__mn__main values (25, 'localph1', 1, 0);
insert into b__mn__main values (26, 'remoteph1', 1, 0);
insert into b__mn__main values (31, 'pval1', 0, 1);
insert into b__mn__main values (32, 'afval1', 0, 1);
insert into b__mn__main values (33, 'mvala1', 0, 1);
insert into b__mn__main values (34, 'mvalb1', 0, 1);
insert into b__mn__main values (35, 'localph1', 0, 1);
insert into b__mn__main values (36, 'remoteph1', 0, 1);
insert into b__mn__main values (41, 'pval1', 1, 1);
insert into b__mn__main values (42, 'afval1', 1, 1);
insert into b__mn__main values (43, 'mvala1', 1, 1);
insert into b__mn__main values (44, 'mvalb1', 1, 1);
insert into b__mn__main values (45, 'localph1', 1, 1);
insert into b__mn__main values (46, 'remoteph1', 1, 1);
alter table b__mn__main add plainb varchar(10);
update b__mn__main set plainb=plain;
alter table b__mn__main add plainbfilt varchar(10);
update b__mn__main set plainbfilt=plain;
create table c__mn__main (
		main_id_key integer,
		plain varchar(10),
		with_dim1_bool integer default 0,
		with_dim2_bool integer default 0 
	);
insert into c__mn__main values (11, 'pval1', 0, 0);
insert into c__mn__main values (12, 'afval1', 0, 0);
insert into c__mn__main values (13, 'mvala1', 0, 0);
insert into c__mn__main values (14, 'mvalb1', 0, 0);
insert into c__mn__main values (15, 'localph1', 0, 0);
insert into c__mn__main values (16, 'remoteph1', 0, 0);
insert into c__mn__main values (21, 'pval1', 1, 0);
insert into c__mn__main values (22, 'afval1', 1, 0);
insert into c__mn__main values (23, 'mvala1', 1, 0);
insert into c__mn__main values (24, 'mvalb1', 1, 0);
insert into c__mn__main values (25, 'localph1', 1, 0);
insert into c__mn__main values (26, 'remoteph1', 1, 0);
insert into c__mn__main values (31, 'pval1', 0, 1);
insert into c__mn__main values (32, 'afval1', 0, 1);
insert into c__mn__main values (33, 'mvala1', 0, 1);
insert into c__mn__main values (34, 'mvalb1', 0, 1);
insert into c__mn__main values (35, 'localph1', 0, 1);
insert into c__mn__main values (36, 'remoteph1', 0, 1);
insert into c__mn__main values (41, 'pval1', 1, 1);
insert into c__mn__main values (42, 'afval1', 1, 1);
insert into c__mn__main values (43, 'mvala1', 1, 1);
insert into c__mn__main values (44, 'mvalb1', 1, 1);
insert into c__mn__main values (45, 'localph1', 1, 1);
insert into c__mn__main values (46, 'remoteph1', 1, 1);
alter table c__mn__main add plainc varchar(10);
update c__mn__main set plainc=plain;
alter table c__mn__main add plaincfilt varchar(10);
update c__mn__main set plaincfilt=plain;

create table a__dim1__dm (
		main_id_key integer,
		lista varchar(10),
		listb varchar(10),
		listc varchar(10)
	);
insert into a__dim1__dm values (21, 'alista21','alistb21','alistc21');
insert into a__dim1__dm values (22, 'alista22','alistb22','alistc22');
insert into a__dim1__dm values (23, 'alista23','alistb23','alistc23');
insert into a__dim1__dm values (24, 'alista24','alistb24','alistc24');
insert into a__dim1__dm values (25, 'alista25','alistb25','alistc25');
insert into a__dim1__dm values (26, 'alista26','alistb26','alistc26');
insert into a__dim1__dm values (41, 'alista41','alistb41','alistc41');
insert into a__dim1__dm values (42, 'alista42','alistb42','alistc42');
insert into a__dim1__dm values (43, 'alista43','alistb43','alistc43');
insert into a__dim1__dm values (44, 'alista44','alistb44','alistc44');
insert into a__dim1__dm values (45, 'alista45','alistb45','alistc45');
insert into a__dim1__dm values (46, 'alista46','alistb46','alistc46');
create table b__dim1__dm (
		main_id_key integer,
		lista varchar(10),
		listb varchar(10),
		listc varchar(10)
	);
insert into b__dim1__dm values (21, 'blista21','blistb21','blistc21');
insert into b__dim1__dm values (22, 'blista22','blistb22','blistc22');
insert into b__dim1__dm values (23, 'blista23','blistb23','blistc23');
insert into b__dim1__dm values (24, 'blista24','blistb24','blistc24');
insert into b__dim1__dm values (25, 'blista25','blistb25','blistc25');
insert into b__dim1__dm values (26, 'blista26','blistb26','blistc26');
insert into b__dim1__dm values (41, 'blista41','blistb41','blistc41');
insert into b__dim1__dm values (42, 'blista42','blistb42','blistc42');
insert into b__dim1__dm values (43, 'blista43','blistb43','blistc43');
insert into b__dim1__dm values (44, 'blista44','blistb44','blistc44');
insert into b__dim1__dm values (45, 'blista45','blistb45','blistc45');
insert into b__dim1__dm values (46, 'blista46','blistb46','blistc46');
create table c__dim1__dm (
		main_id_key integer,
		lista varchar(10),
		listb varchar(10),
		listc varchar(10)
	);
insert into c__dim1__dm values (21, 'clista21','clistb21','clistc21');
insert into c__dim1__dm values (22, 'clista22','clistb22','clistc22');
insert into c__dim1__dm values (23, 'clista23','clistb23','clistc23');
insert into c__dim1__dm values (24, 'clista24','clistb24','clistc24');
insert into c__dim1__dm values (25, 'clista25','clistb25','clistc25');
insert into c__dim1__dm values (26, 'clista26','clistb26','clistc26');
insert into c__dim1__dm values (41, 'clista41','clistb41','clistc41');
insert into c__dim1__dm values (42, 'clista42','clistb42','clistc42');
insert into c__dim1__dm values (43, 'clista43','clistb43','clistc43');
insert into c__dim1__dm values (44, 'clista44','clistb44','clistc44');
insert into c__dim1__dm values (45, 'clista45','clistb45','clistc45');
insert into c__dim1__dm values (46, 'clista46','clistb46','clistc46');

create table a__dim2__dm (
		main_id_key integer,
		seqname varchar(10),
		plainseq text
	);
insert into a__dim2__dm values (31, 'aseqname31','a31ATGCTAGTCGATCGATATACTGATCGTAGCTAGTCAG');
insert into a__dim2__dm values (32, 'aseqname32','a32TGCTAGTCGATCGATATACTGATCGTAGCTAGTCAGA');
insert into a__dim2__dm values (33, 'aseqname33','a33GCTAGTCGATCGATATACTGATCGTAGCTAGTCAGTG');
insert into a__dim2__dm values (34, 'aseqname34','a34CTAGTCGATCGATATACTGATCGTAGCTAGTCAGATC');
insert into a__dim2__dm values (35, 'aseqname35','a35TAGTCGATCGATATACTGATCGTAGCTAGTCAGATCG');
insert into a__dim2__dm values (36, 'aseqname36','a36AGTCGATCGATATACTGATCGTAGCTAGTCAGATCAA');
insert into a__dim2__dm values (41, 'aseqname41','a41TGACATGCTAGTCGATCGATATACTGATCGTAGCTAGTCAG');
insert into a__dim2__dm values (42, 'aseqname42','a42ATCCTGCTAGTCGATCGATATACTGATCGTAGCTAGTCAGA');
insert into a__dim2__dm values (43, 'aseqname43','a43AGTCGCTAGTCGATCGATATACTGATCGTAGCTAGTCAGTG');
insert into a__dim2__dm values (44, 'aseqname44','a44TCACCTAGTCGATCGATATACTGATCGTAGCTAGTCAGATC');
insert into a__dim2__dm values (45, 'aseqname45','a45CATCTAGTCGATCGATATACTGATCGTAGCTAGTCAGATCG');
insert into a__dim2__dm values (46, 'aseqname46','a46GGGAGGTCGATCGATATACTGATCGTAGCTAGTCAGATCAA');
create table b__dim2__dm (
		main_id_key integer,
		seqname varchar(10),
		plainseq text
	);
insert into b__dim2__dm values (31, 'bseqname31','b31ATGCTAGTCGATCGATATACTGATCGTAGCTAGTCAG');
insert into b__dim2__dm values (32, 'bseqname32','b32TGCTAGTCGATCGATATACTGATCGTAGCTAGTCAGA');
insert into b__dim2__dm values (33, 'bseqname33','b33GCTAGTCGATCGATATACTGATCGTAGCTAGTCAGTG');
insert into b__dim2__dm values (34, 'bseqname34','b34CTAGTCGATCGATATACTGATCGTAGCTAGTCAGATC');
insert into b__dim2__dm values (35, 'bseqname35','b35TAGTCGATCGATATACTGATCGTAGCTAGTCAGATCG');
insert into b__dim2__dm values (36, 'bseqname36','b36AGTCGATCGATATACTGATCGTAGCTAGTCAGATCAA');
insert into b__dim2__dm values (41, 'bseqname41','b41TGACATGCTAGTCGATCGATATACTGATCGTAGCTAGTCAG');
insert into b__dim2__dm values (42, 'bseqname42','b42ATCCTGCTAGTCGATCGATATACTGATCGTAGCTAGTCAGA');
insert into b__dim2__dm values (43, 'bseqname43','b43AGTCGCTAGTCGATCGATATACTGATCGTAGCTAGTCAGTG');
insert into b__dim2__dm values (44, 'bseqname44','b44TCACCTAGTCGATCGATATACTGATCGTAGCTAGTCAGATC');
insert into b__dim2__dm values (45, 'bseqname45','b45CATCTAGTCGATCGATATACTGATCGTAGCTAGTCAGATCG');
insert into b__dim2__dm values (46, 'bseqname46','b46GGGAGGTCGATCGATATACTGATCGTAGCTAGTCAGATCAA');
create table c__dim2__dm (
		main_id_key integer,
		seqname varchar(10),
		plainseq text
	);
insert into c__dim2__dm values (31, 'cseqname31','c31ATGCTAGTCGATCGATATACTGATCGTAGCTAGTCAG');
insert into c__dim2__dm values (32, 'cseqname32','c32TGCTAGTCGATCGATATACTGATCGTAGCTAGTCAGA');
insert into c__dim2__dm values (33, 'cseqname33','c33GCTAGTCGATCGATATACTGATCGTAGCTAGTCAGTG');
insert into c__dim2__dm values (34, 'cseqname34','c34CTAGTCGATCGATATACTGATCGTAGCTAGTCAGATC');
insert into c__dim2__dm values (35, 'cseqname35','c35TAGTCGATCGATATACTGATCGTAGCTAGTCAGATCG');
insert into c__dim2__dm values (36, 'cseqname36','c36AGTCGATCGATATACTGATCGTAGCTAGTCAGATCAA');
insert into c__dim2__dm values (41, 'cseqname41','c41TGACATGCTAGTCGATCGATATACTGATCGTAGCTAGTCAG');
insert into c__dim2__dm values (42, 'cseqname42','c42ATCCTGCTAGTCGATCGATATACTGATCGTAGCTAGTCAGA');
insert into c__dim2__dm values (43, 'cseqname43','c43AGTCGCTAGTCGATCGATATACTGATCGTAGCTAGTCAGTG');
insert into c__dim2__dm values (44, 'cseqname44','c44TCACCTAGTCGATCGATATACTGATCGTAGCTAGTCAGATC');
insert into c__dim2__dm values (45, 'cseqname45','c45CATCTAGTCGATCGATATACTGATCGTAGCTAGTCAGATCG');
insert into c__dim2__dm values (46, 'cseqname46','c46GGGAGGTCGATCGATATACTGATCGTAGCTAGTCAGATCAA');
