/*
 * This file is part of the Substack Analysis (SUSAN) framework.
 * Copyright (c) 2018-2021 Ricardo Miguel Sanchez Loayza.
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Affero General Public License as
 * published by the Free Software Foundation, either version 3 of the
 * License, or (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Affero General Public License for more details.
 * 
 * You should have received a copy of the GNU Affero General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <getopt.h>
#include <unistd.h>

#include "io.h"
#include "tomogram.h"
#include "particles.h"
#include "reference.h"
#include "ctf_refiner.h"
#include "ctf_refiner_args.h"
#include "mpi_iface.h"
#include "progress.h"

class CtfRefinerPoolMpi : public CtfRefinerPool {

public:
    MpiInterface*mpi_iface;
    MpiProgress *mpi_progress;

    CtfRefinerPoolMpi(ArgsCtfRef::Info*info,References*in_p_refs,int in_max_K,int num_ptcls,StackReader&stkrdr,int in_num_threads)
        : CtfRefinerPool(info,in_p_refs,in_max_K,num_ptcls,stkrdr,in_num_threads)
    {
    }

    void set_mpi(MpiInterface*in_mpi_iface,MpiProgress*in_mpi_progress,Particles*ptcls_full) {
        mpi_iface = in_mpi_iface;
        mpi_progress = in_mpi_progress;
        unsigned int val = 0;
        mpi_progress->put( mpi_iface->node_id, val );

        if( mpi_iface->is_main_node() ) {
            n_ptcls = ptcls_full->n_ptcl;
        }
    }

protected:
    unsigned int count_progress_mpi() {
        unsigned int rslt = 0;
        if( mpi_iface->is_main_node() ) {
            for(unsigned int i=0;i<mpi_iface->num_nodes;i++) {
                rslt += mpi_progress->get(i);
            }
        }
        return rslt;
    }

    void progress_start() {
        if( mpi_iface->is_main_node() ) {
            CtfRefinerPool::progress_start();
        }
    }

    void show_progress(const int ptcls_in_tomo) {

        while( (count_progress()) < ptcls_in_tomo ) {
            unsigned int local_progress = count_accumul();
            mpi_progress->put( mpi_iface->node_id, local_progress );

            if( mpi_iface->is_main_node() ) {
                unsigned int total_progress = count_progress_mpi();
                progress.update(total_progress,false);
            }
            sleep(3);
        } /// while
    }

    void show_done() {
        if( mpi_iface->is_main_node() ) {
            progress.finish();
        }
    }
};

void print_data_info(Particles*ptcls,Tomograms&tomos,ArgsCtfRef::Info&info) {
    if(info.verbosity>0) {
        printf("\t\tAvailable particles:  %d.\n",ptcls->n_ptcl);
        printf("\t\tNumber of classes:    %d.\n",ptcls->n_refs);
        printf("\t\tTomograms available:  %d.\n",tomos.num_tomo);
        printf("\t\tAvailabe projections: %d (max).\n",tomos.num_proj);
    }
    else {
       printf("    - %d Particles (%d classes) in %d tomograms with max %d projections.\n",ptcls->n_ptcl,ptcls->n_refs,tomos.num_tomo,tomos.num_proj);
    }
}

int main(int ac, char** av) {

    MpiInterface mpi_iface;
    ArgsCtfRef::Info info;

    if( ArgsCtfRef::parse_args(info,ac,av) ) {

        if( mpi_iface.is_main_node() ) {
            ArgsCtfRef::print(info);
            mpi_iface.print_info(info.verbosity);
        }

        PBarrier barrier(2);
        ParticlesRW*ptcls_io;
        MpiScatterInfo scatter_info(mpi_iface.num_nodes);
        MpiProgress mpi_progress(mpi_iface.num_nodes);

        if( mpi_iface.is_main_node() ) {
            printf("\tLoading and scattering data files...");
            fflush(stdout);
        }

        References refs(info.refs_file);
        Tomograms tomos(info.tomo_file);

        if( mpi_iface.is_main_node() ) {
            ptcls_io = new ParticlesRW(info.ptcls_in);
        }

        Particles*ptcls = mpi_iface.scatter_particles(scatter_info,ptcls_io);

        if( mpi_iface.is_main_node() ) {
            printf(" Done\n");
            fflush(stdout);
        }

        if( mpi_iface.is_main_node() ) {
            print_data_info(ptcls_io,tomos,info);
        }

        StackReader stkrdr(ptcls,&tomos,&barrier);
        CtfRefinerPoolMpi pool(&info,&refs,tomos.num_proj,ptcls->n_ptcl,stkrdr,info.n_threads);
        pool.set_mpi(&mpi_iface,&mpi_progress,ptcls_io);

        stkrdr.start();
        pool.start();

        stkrdr.wait();
        pool.wait();

        if( mpi_iface.is_main_node() ) {
            printf("\tGathering data files...");
            fflush(stdout);
        }

        mpi_iface.gather_particles(ptcls,scatter_info,ptcls_io);

        if( mpi_iface.is_main_node() ) {
            ptcls_io->save(info.ptcls_out);
            printf(" Done\n");
            fflush(stdout);
        }

        mpi_iface.delete_scattered_ptcls(ptcls);

        if( mpi_iface.is_main_node() ) {
            delete ptcls_io;
        }
    }
    else {
        fprintf(stderr,"Error parsing input arguments.\n");
        exit(1);
    }
	
    return 0;
}



