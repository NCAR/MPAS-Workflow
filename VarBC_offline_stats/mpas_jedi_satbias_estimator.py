#!/usr/bin/env python3
# Description: The tool is used to generate the VarBC coefficient and variance for the MPAS-JEDI radiance DA. 
# Date: Mar. 2025, initial version
import numpy  as np
np.set_printoptions(precision=2)
import h5py
import os,sys

# obsout from da
qcGroupName  = 'EffectiveQC'
obsGroupName = 'ObsValue'
hofxGroupName= 'hofx'
biasGroupName= 'ObsBias'
errGroupName = 'EffectiveError'

class ObsoutReader():
    def __init__(self,fname):
        # db_dict structure: {(groupname,ch):list(values)}.
        # db_dict hold all values read from multi obsout files
        self.db_dict = {} 
        # extract predictor and channel information from the first file
        with h5py.File(fname, "r") as f:
            keys  = list(f.keys())
            self.predictorNames   = []
            for key in keys:
                if key.endswith('Predictor'):
                    self.predictorNames.append(key.replace("Predictor",""))
            self.channels = list(f['Channel'][:])
    
    def _readGroupbyName(self,hdf5,groupname):
        # private function
        group   = hdf5[groupname]
        # each group have one variable in obsout, so get the first variable
        varname = group[list(group.keys())[0]].name
        var2d     = hdf5[varname]
        return var2d[:,:] #(location,channel)
    
    def _add_QCedVar_to_db_dict(self,hdf5,groupname):
        # private function
        var2d = self._readGroupbyName(hdf5,groupname)
        qc2d  = self._readGroupbyName(hdf5,qcGroupName)
        for ch in self.channels:
            ich   = self.channels.index(ch)
            index = qc2d[:,ich] == 0
            if len(index) > 0:
                var_qced = var2d[index,ich]
            else:
                var_qced = var2d[:,ich]
            if (groupname,ch) not in self.db_dict.keys():
                # initialize db_dict[key] with list(var_qced)
                self.db_dict[(groupname,ch)] = list(var_qced)
            else:
                # append list(var_qced)
                self.db_dict[(groupname,ch)].extend(list(var_qced))
    
    def update_tlaps_mean(self,tlapmean_input,tlapmean_output):
        self.tlaps_mean = np.zeros(len(self.channels))
        instrument = ""
        # read in tlaps_mean txt file
        if os.path.exists(tlapmean_input):
            with open(tlapmean_input, "r") as f:
                for line in f:
                    parts = line.split()
                    instrument = parts[0]
                    channel = int(parts[1])
                    value = float(parts[2])
                    if channel in self.channels:
                        ich  = self.channels.index(channel)
                        self.tlaps_mean[ich] = value
        else:
            print("Warnning: tlaps_mean.txt not exist, not update tlaps mean.")
        
        # compute origional tlapse        
        for ch in self.channels:
            ich        = self.channels.index(ch)
            tlapseList = self.db_dict[("lapseRate"+"Predictor",ch)] # list
            tmean      = self.tlaps_mean[ich]
            tlapse_org = np.array(tlapseList) + tmean 
            self.db_dict[("lapseRate"+"Predictor",ch)] = list(tlapse_org)
            self.db_dict[("lapseRate_order_2"+"Predictor",ch)] = list(tlapse_org**2)
        # recompute tlapse mean
        with open(tlapmean_output, "w") as f:
            for ch in self.channels:
                ich        = self.channels.index(ch)      
                tlapseList = self.db_dict[("lapseRate"+"Predictor",ch)] # list      
                tlapse_org = np.array(tlapseList)
                if len(tlapse_org) > 0:
                    tmean  = np.mean(tlapse_org)
                else:
                    # no observation to recompute tlaps mean,keep 0
                    tmean  = 0
                tlapse     = tlapse_org - tmean
                self.db_dict[("lapseRate"+"Predictor",ch)] = list(tlapse)
                self.db_dict[("lapseRate_order_2"+"Predictor",ch)] = list(tlapse**2)
                f.write(f"{instrument} {ch} {tmean:.6E}\n")
            
    def add_file(self,fname): 
        print("read",fname)
        with h5py.File(fname, "r") as f:
            for key in self.predictorNames:
                self._add_QCedVar_to_db_dict(f,key+"Predictor")
            for key in [obsGroupName,hofxGroupName,biasGroupName,errGroupName]:
                self._add_QCedVar_to_db_dict(f,key)
    
    def get_channels(self):
        return self.channels
    
    def get_predNames(self):
        return self.predictorNames
    
    def get_Predictor(self,channel):
        res2d = []
        for predName in self.predictorNames:
            key    = (predName+"Predictor",channel)
            values = self.db_dict[key]
            res2d.append(values)
        pred_8xn = np.array(res2d).astype(np.float64)
        return pred_8xn
    
    def get_Yd(self,channel):
        obs = self.db_dict[(obsGroupName,channel)]
        hofx= self.db_dict[(hofxGroupName,channel)]
        bias= self.db_dict[(biasGroupName,channel)]
        Yd_nx1 = np.array(obs) - np.array(hofx) + np.array(bias)
        Yd_nx1 = Yd_nx1.astype(np.float64)
        return Yd_nx1
    
    def get_Rinv(self,channel):
        err  = self.db_dict[(errGroupName,channel)]
        err  = np.array(err,dtype=np.float64)
        #err[err==0] = 1e-20
        Rinv = 1.0/err
        return Rinv          

class SatbiasIO():
    def __init__(self,predictorNames,channels):
        nch = len(channels)
        self.predictorNames = predictorNames
        self.channels       = channels
        self.num_obs_used = np.zeros(nch)
        # beta_dict: {'predname':[beta of nChannels]}
        self.beta_dict = {}
        self.err_dict  = {}
        for key in predictorNames:
            self.beta_dict[key] = np.zeros(nch, dtype=np.float64)
            self.err_dict[key]  = 1e20*np.ones(nch, dtype=np.float64)
    
    def readin_satbias_beta(self,fname,groupname='BiasCoefficients'):
        inflation_factor = 1.1
        if os.path.exists(fname):
            with h5py.File(fname, "r") as hdf5:
                group  = hdf5[groupname]
                for key in list(group.keys()):
                    varname = group[key].name
                    var2d   = hdf5[varname]  #(1,nch)
                    if groupname=='BiasCoefficients':
                        self.beta_dict[key] = var2d[0,:]
                    elif groupname == 'BiasCoefficientErrors':
                        self.err_dict[key]  = inflation_factor * var2d[0,:]
        else:
            print("Warnning: initial satbias not exist, starting from ZERO beta")
    
    def readin_satbias_err(self,fname,groupname='BiasCoefficientErrors'):
        self.readin_satbias_beta(fname,groupname=groupname)            
    
    def getBeta(self,channel):
        beta = []
        ich  = self.channels.index(channel)
        for key in self.predictorNames:
            beta.append(self.beta_dict[key][ich])
        beta = np.array(beta)
        beta_8x1 = beta.T
        return beta_8x1
    
    def setBeta(self,key,channel,value):
        ich  = self.channels.index(channel)
        self.beta_dict[key][ich] = value
    
    def getCov(self,channel):
        err = []
        ich  = self.channels.index(channel)
        for key in self.predictorNames:
            err.append(self.err_dict[key][ich])
        B = np.diag(err)
        return B 
    
    def setCov(self,key,channel,value):
        ich  = self.channels.index(channel)
        self.err_dict[key][ich] = value

    def setNumObsUsed(self,channel,value):
        ich  = self.channels.index(channel)
        self.num_obs_used[ich] = value
           
    def _addLabel_to_hdf5Varialbe(self,f,varname,data_dim1,data_dim2):
        h5var = f[varname]
        h5var.dims[0].attach_scale(data_dim1)
        h5var.dims[1].attach_scale(data_dim2)

    def save(self,outname):
        n_Records = 1
        shape     = (n_Records, len(self.channels))
        # Create the HDF5 file for writing
        with h5py.File(outname, "w") as f:
            # Set global attributes
            f.attrs["_ioda_layout"] = "ObsGroup"
            f.attrs["_ioda_layout_version"] = 0
            # Create root-level datasets    
            var_channel  = f.create_dataset("Channel", data=np.array(self.channels),    dtype=np.int32)       
            var_record   = f.create_dataset("Record",  data=np.array(range(n_Records)), dtype=np.int32)
            # write Number of Observation Used
            num_obs_used = self.num_obs_used.reshape(shape)
            var_num      = f.create_dataset("numberObservationsUsed", data=num_obs_used,dtype=np.int32)      
            self._addLabel_to_hdf5Varialbe(f,'numberObservationsUsed',var_record,var_channel)
            # write for each predictor
            group_beta = f.create_group("BiasCoefficients")       
            group_err  = f.create_group("BiasCoefficientErrors")            
            for key in self.beta_dict.keys():
                beta= self.beta_dict[key].reshape(shape)
                err = self.err_dict[key].reshape(shape)
                ds_beta = group_beta.create_dataset(key,data=beta,dtype=np.float32)
                ds_err  = group_err.create_dataset(key,data=err,dtype=np.float32)
                self._addLabel_to_hdf5Varialbe(f,'BiasCoefficients/'+key, var_record,var_channel)
                self._addLabel_to_hdf5Varialbe(f,'BiasCoefficientErrors/'+key, var_record,var_channel)
        print("Updated satbias to ",outname)  

class MPAS_JEDI_BiasCorrection():
    def __init__(self,obsout_reader,satbias_io):
        self.obsout_reader = obsout_reader
        self.satbias_io    = satbias_io
        self.channels      = obsout_reader.get_channels()
        self.predNames     = obsout_reader.get_predNames() 

    def solve_beta(self,channel):
        ich   = self.channels.index(channel)
        # hessian: [B^-1 + P @ R^-1 @ P^T]
        # beta =   [B^-1 + P @ R^-1 @ P^T]^-1 [B^-1@beta0 + P @ R^-1 @ Yd]
        pred_8xn = self.obsout_reader.get_Predictor(channel)
        Rinv     = self.obsout_reader.get_Rinv(channel)
        Yd_nx1   = self.obsout_reader.get_Yd(channel)
        beta     = self.satbias_io.getBeta(channel)
        B        = self.satbias_io.getCov(channel)        
        #Binv     = np.linalg.inv(B)
        Binv     = np.linalg.pinv(B)
        #self.print_residual("BEFORE:",channel,pred_8xn,beta,Yd_nx1)        
        # solve beta
        P_Rinv    = pred_8xn * Rinv[None, :]  #pred_8xn @ Rinv
        P_Rinv_Pt = P_Rinv @ pred_8xn.T        
        hessian   = Binv + P_Rinv_Pt
        A         = np.linalg.pinv(hessian)
        term2 = Binv @ beta + P_Rinv @ Yd_nx1        
        beta  = A @ term2        
        for i in range(len(self.predNames)):
            key = self.predNames[i]
            self.satbias_io.setBeta(key,channel,beta[i])
            self.satbias_io.setCov (key,channel,A[i,i])
        self.satbias_io.setNumObsUsed (channel,len(Yd_nx1))        
        self.beta = beta
        self.print_residual("UPDATE:",channel,pred_8xn,beta,Yd_nx1)
        #print("-----------------------")
        return beta,hessian
    
    def print_residual(self,prefix,channel,pred_8xn,beta,Yd_nx1):        
        shape   = pred_8xn.shape
        nObs    = shape[1]
        #if nObs == 0:
        #    return
        obsbias = pred_8xn.T @ beta
        omb_bc  = Yd_nx1 - obsbias
        string  = "%s ch%d "%(prefix,channel)
        if nObs>0:
            string += " RMS(omb_bc)= %.2f "%np.sqrt(np.mean(omb_bc**2))
            string += " MEAN(omb_bc)= %8.4f "%np.mean(omb_bc)
            string += " obsbias= %.2f ["%np.mean(obsbias)
            for i in range(len(self.predNames)):
                key   = self.predNames[i]
                bias  = pred_8xn.T[:,i:i+1] @ beta[i:i+1] # beta[i:i+1] is the ith beta value
                string += " %.2f "%(np.mean(bias))
            string += "]"
        else:
            string += " no valid observations"
        print(string)
        
    def update(self):
        for ch in self.channels:
            self.solve_beta(ch)       

    def save(self,outname):
        self.satbias_io.save(outname)     


# =========================================================
if __name__ == "__main__":
    if len(sys.argv) < 5:
        print("Usage: python %s \"obsout_fnames\" tlapmean_input tlapmean_output satbias_input satbias_output "%sys.argv[0])
        sys.exit(0)
    obsout_fnames=sys.argv[1].split()
    tlapmean_input = sys.argv[2]
    tlapmean_output= sys.argv[3]
    satbias_input  = sys.argv[4]
    satbias_output = sys.argv[5]
    update_tlaps_mean = True 
    print("obsout_fnames:",obsout_fnames[0])
    print("tlapmean_input:",tlapmean_input)
    print("tlapmean_output:",tlapmean_output)
    print("satbias_input:",satbias_input)
    print("satbias_output:",satbias_output)
    
    if '_da_' in obsout_fnames[0]:
        # obsout from da
        qcGroupName  = 'EffectiveQC0'
        obsGroupName = 'ObsValue'
        hofxGroupName= 'hofx0'
        biasGroupName= 'ObsBias0'
        errGroupName = 'EffectiveError0'
    else:
        # obsout from hofx
        qcGroupName  = 'EffectiveQC'
        obsGroupName = 'ObsValue'
        hofxGroupName= 'hofx'
        biasGroupName= 'ObsBias'
        errGroupName = 'EffectiveError'
    #=================================
    # run the estimator
    obsout = ObsoutReader(obsout_fnames[0])    
    for fname in obsout_fnames:
        obsout.add_file(fname)
    if update_tlaps_mean == True:
        obsout.update_tlaps_mean(tlapmean_input,tlapmean_output)
    predNames = obsout.get_predNames()
    channels  = obsout.get_channels()
    satbias   = SatbiasIO(predNames,channels)    
    satbias.readin_satbias_beta(satbias_input)
    satbias.readin_satbias_err(satbias_input)
    bc = MPAS_JEDI_BiasCorrection(obsout,satbias)
    bc.update()
    bc.save(satbias_output)

